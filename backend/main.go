package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/exec"
	"sync"
)

type RecordingState struct {
	IsRecording bool   `json:"is_recording"`
	OutputFile  string `json:"output_file,omitempty"`
}

type Response struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
}

var (
	recordingState = RecordingState{IsRecording: false}
	stateMutex     sync.Mutex
	cmd            *exec.Cmd
)

func main() {
	http.HandleFunc("/api/start-recording", startRecordingHandler)
	http.HandleFunc("/api/stop-recording", stopRecordingHandler)
	http.HandleFunc("/api/status", statusHandler)

	// Enable CORS
	corsHandler := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusOK)
				return
			}
			next.ServeHTTP(w, r)
		})
	}

	server := &http.Server{
		Addr:    ":8080",
		Handler: corsHandler(http.DefaultServeMux),
	}

	log.Println("Server starting on :8080...")
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

func startRecordingHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	stateMutex.Lock()
	defer stateMutex.Unlock()

	if recordingState.IsRecording {
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "Recording is already in progress",
		})
		return
	}

	// Create output directory if not exists
	outputDir := "./recordings"
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		log.Printf("Failed to create output directory: %v", err)
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "Failed to create output directory",
		})
		return
	}

	// Generate output filename
	outputFile := outputDir + "/recording.mp4"
	recordingState.OutputFile = outputFile

	// For macOS, use ffmpeg for screen recording
	// Make sure ffmpeg is installed: brew install ffmpeg
	cmd = exec.Command("ffmpeg",
		"-f", "avfoundation",
		"-i", "1:0", // 1 is usually the screen, 0 is audio
		"-r", "30",
		"-c:v", "libx264",
		"-preset", "ultrafast",
		"-c:a", "aac",
		"-strict", "experimental",
		"-y", // Overwrite output file
		outputFile,
	)

	// Redirect stderr for debugging
	cmd.Stderr = os.Stderr
	cmd.Stdout = os.Stdout

	if err := cmd.Start(); err != nil {
		log.Printf("Failed to start recording: %v", err)
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "Failed to start recording: " + err.Error(),
		})
		return
	}

	recordingState.IsRecording = true
	log.Printf("Recording started: %s", outputFile)

	json.NewEncoder(w).Encode(Response{
		Success: true,
		Message: "Recording started successfully",
	})
}

func stopRecordingHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	stateMutex.Lock()
	defer stateMutex.Unlock()

	if !recordingState.IsRecording {
		json.NewEncoder(w).Encode(Response{
			Success: false,
			Message: "No recording in progress",
		})
		return
	}

	if cmd != nil && cmd.Process != nil {
		// Send SIGINT to ffmpeg to stop recording gracefully
		if err := cmd.Process.Signal(os.Interrupt); err != nil {
			log.Printf("Failed to send interrupt signal: %v", err)
			// Fallback to kill if interrupt fails
			if err := cmd.Process.Kill(); err != nil {
				log.Printf("Failed to kill process: %v", err)
			}
		}

		// Wait for the process to exit
		if err := cmd.Wait(); err != nil {
			log.Printf("Process wait error: %v", err)
		}
	}

	recordingState.IsRecording = false
	log.Printf("Recording stopped: %s", recordingState.OutputFile)

	json.NewEncoder(w).Encode(Response{
		Success: true,
		Message: "Recording stopped successfully. Saved to: " + recordingState.OutputFile,
	})
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	stateMutex.Lock()
	defer stateMutex.Unlock()

	json.NewEncoder(w).Encode(recordingState)
}
