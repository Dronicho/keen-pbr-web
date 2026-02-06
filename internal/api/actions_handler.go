package api

import (
	"encoding/json"
	"keen-pbr-web/internal/config"
	"net/http"
	"os/exec"
	"strings"
)

type ActionResult struct {
	Success bool   `json:"success"`
	Output  string `json:"output"`
}

func (s *Server) handleDownload(w http.ResponseWriter, _ *http.Request) {
	result := runCommand("keen-pbr", "download")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (s *Server) handleApply(w http.ResponseWriter, _ *http.Request) {
	var outputs []string

	r1 := runCommand("/opt/etc/init.d/S80keen-pbr", "restart")
	outputs = append(outputs, "=== keen-pbr restart ===\n"+r1.Output)

	r2 := runCommand("/opt/etc/init.d/S56dnsmasq", "restart")
	outputs = append(outputs, "=== dnsmasq restart ===\n"+r2.Output)

	result := ActionResult{
		Success: r1.Success && r2.Success,
		Output:  strings.Join(outputs, "\n\n"),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (s *Server) handleSelfCheck(w http.ResponseWriter, _ *http.Request) {
	result := runCommand("keen-pbr", "self-check")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (s *Server) handleUndoRouting(w http.ResponseWriter, _ *http.Request) {
	result := runCommand("keen-pbr", "undo-routing")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (s *Server) handleInterfaces(w http.ResponseWriter, _ *http.Request) {
	result := runCommand("keen-pbr", "interfaces")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (s *Server) handleDnsmasqConfig(w http.ResponseWriter, _ *http.Request) {
	result := runCommand("keen-pbr", "print-dnsmasq-config")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (s *Server) handleDns(w http.ResponseWriter, _ *http.Request) {
	result := runCommand("keen-pbr", "dns")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

type StatusInfo struct {
	ConfigPath  string `json:"config_path"`
	ListsCount  int    `json:"lists_count"`
	IPSetsCount int    `json:"ipsets_count"`
}

func (s *Server) handleStatus(w http.ResponseWriter, _ *http.Request) {
	status := StatusInfo{
		ConfigPath: s.configPath,
	}

	cfg, err := config.Load(s.configPath)
	if err == nil {
		status.ListsCount = len(cfg.Lists)
		status.IPSetsCount = len(cfg.IPSets)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

func runCommand(name string, args ...string) ActionResult {
	cmd := exec.Command(name, args...)
	output, err := cmd.CombinedOutput()
	return ActionResult{
		Success: err == nil,
		Output:  string(output),
	}
}
