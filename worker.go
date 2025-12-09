package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"k8s.io/klog/v2"
)

// FileProcessor implements LeaderWorker for file processing
type FileProcessor struct {
	dataDir string
	id      string
}

// NewFileProcessor creates a new file processor
func NewFileProcessor(dataDir, id string) *FileProcessor {
	// Ensure directories exist
	os.MkdirAll(filepath.Join(dataDir, "pending"), 0755)
	os.MkdirAll(filepath.Join(dataDir, "done"), 0755)

	return &FileProcessor{dataDir: dataDir, id: id}
}

// Start begins processing files (only called when leader)
func (p *FileProcessor) Start(ctx context.Context) {
	klog.InfoS("File processor started", "id", p.id)

	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			klog.Info("File processor stopped")
			return
		case <-ticker.C:
			p.processAllFiles(ctx)
		}
	}
}

// Stop is called when leadership is lost
func (p *FileProcessor) Stop() {
	klog.InfoS("File processor stopping", "id", p.id)
}

func (p *FileProcessor) processAllFiles(ctx context.Context) {
	pending := filepath.Join(p.dataDir, "pending")
	done := filepath.Join(p.dataDir, "done")

	files, err := os.ReadDir(pending)
	if err != nil || len(files) == 0 {
		return
	}

	for _, f := range files {
		if f.IsDir() {
			continue
		}

		// Check if we lost leadership
		select {
		case <-ctx.Done():
			return
		default:
		}

		p.processFile(filepath.Join(pending, f.Name()), filepath.Join(done, f.Name()))
	}
}

func (p *FileProcessor) processFile(src, dst string) {
	name := filepath.Base(src)
	klog.InfoS("Processing", "file", name, "leader", p.id)

	// Simulate work
	time.Sleep(2 * time.Second)

	// Read, stamp, move
	data, _ := os.ReadFile(src)
	result := fmt.Sprintf("%s\n[Processed by %s at %s]\n",
		string(data), p.id, time.Now().Format(time.RFC3339))
	os.WriteFile(dst, []byte(result), 0644)
	os.Remove(src)

	klog.InfoS("Done", "file", name, "leader", p.id)
}
