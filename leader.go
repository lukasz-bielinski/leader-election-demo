package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/leaderelection"
	"k8s.io/client-go/tools/leaderelection/resourcelock"
	"k8s.io/klog/v2"
)

// LeaderWorker defines what the leader does
type LeaderWorker interface {
	Start(ctx context.Context)
	Stop()
}

// RunLeaderElection runs leader election with the given worker
func RunLeaderElection(id, namespace, leaseName string, worker LeaderWorker) {
	config, err := rest.InClusterConfig()
	if err != nil {
		klog.Fatal("Failed to get cluster config: ", err)
	}
	client := kubernetes.NewForConfigOrDie(config)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle shutdown signals
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	go func() {
		<-ch
		klog.Info("Shutdown signal received")
		cancel()
	}()

	lock := &resourcelock.LeaseLock{
		LeaseMeta:  metav1.ObjectMeta{Name: leaseName, Namespace: namespace},
		Client:     client.CoordinationV1(),
		LockConfig: resourcelock.ResourceLockConfig{Identity: id},
	}

	klog.InfoS("Starting leader election", "id", id, "namespace", namespace, "lease", leaseName)

	leaderelection.RunOrDie(ctx, leaderelection.LeaderElectionConfig{
		Lock:            lock,
		ReleaseOnCancel: true,
		LeaseDuration:   15 * time.Second,
		RenewDeadline:   10 * time.Second,
		RetryPeriod:     2 * time.Second,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: func(ctx context.Context) {
				klog.InfoS("Became LEADER", "id", id)
				worker.Start(ctx)
			},
			OnStoppedLeading: func() {
				klog.InfoS("Lost leadership", "id", id)
				worker.Stop()
			},
			OnNewLeader: func(identity string) {
				if identity != id {
					klog.InfoS("New leader elected", "leader", identity, "me", id)
				}
			},
		},
	})
}
