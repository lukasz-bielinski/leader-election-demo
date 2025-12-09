package main

import (
	"flag"
	"os"

	"k8s.io/klog/v2"
)

func main() {
	klog.InitFlags(nil)

	var id, leaseName, namespace string
	flag.StringVar(&id, "id", getEnv("HOSTNAME", "unknown"), "unique instance identity")
	flag.StringVar(&leaseName, "lease-name", getEnv("LEASE_NAME", "leader-election-demo"), "lease name")
	flag.StringVar(&namespace, "namespace", getEnv("NAMESPACE", "default"), "namespace")
	flag.Parse()

	// Create business logic worker
	worker := NewFileProcessor("/data", id)

	// Run leader election with worker callbacks
	RunLeaderElection(id, namespace, leaseName, worker)
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
