package main

import (
	"flag"
	"os"

	"k8s.io/klog/v2"
)

func main() {
	klog.InitFlags(nil)

	var id, leaseName, namespace string
	flag.StringVar(&id, "id", os.Getenv("HOSTNAME"), "unique instance identity")
	flag.StringVar(&leaseName, "lease-name", "leader-election-demo", "lease name")
	flag.StringVar(&namespace, "namespace", os.Getenv("NAMESPACE"), "namespace")
	flag.Parse()

	if namespace == "" {
		namespace = "default"
	}
	if id == "" {
		id = "unknown"
	}

	// Create business logic worker
	worker := NewFileProcessor("/data", id)

	// Run leader election with worker callbacks
	RunLeaderElection(id, namespace, leaseName, worker)
}
