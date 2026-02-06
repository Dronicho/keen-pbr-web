package api

import (
	"encoding/json"
	"keen-pbr-web/internal/config"
	"net/http"
	"os"
	"strings"
)

// ListInfo is the response type for GET /api/lists
type ListInfo struct {
	Name   string   `json:"name"`
	Type   string   `json:"type"` // "inline", "file", "url"
	URL    string   `json:"url,omitempty"`
	File   string   `json:"file,omitempty"`
	Entries []string `json:"entries,omitempty"`
	IPSets []string `json:"ipsets"`
}

func (s *Server) handleGetLists(w http.ResponseWriter, _ *http.Request) {
	cfg, err := config.Load(s.configPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Build reverse map: list_name -> []ipset_name
	listIPSets := make(map[string][]string)
	for _, ipset := range cfg.IPSets {
		for _, listName := range ipset.Lists {
			listIPSets[listName] = append(listIPSets[listName], ipset.IPSetName)
		}
	}

	lists := make([]ListInfo, 0, len(cfg.Lists))
	for _, l := range cfg.Lists {
		info := ListInfo{Name: l.ListName, IPSets: listIPSets[l.ListName]}
		if info.IPSets == nil {
			info.IPSets = []string{}
		}
		switch {
		case l.URL != "":
			info.Type = "url"
			info.URL = l.URL
		case l.File != "":
			info.Type = "file"
			info.File = l.File
		default:
			info.Type = "inline"
		}
		lists = append(lists, info)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(lists)
}

func (s *Server) handleGetList(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	cfg, err := config.Load(s.configPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Build reverse map: list_name -> []ipset_name
	listIPSets := make(map[string][]string)
	for _, ipset := range cfg.IPSets {
		for _, listName := range ipset.Lists {
			listIPSets[listName] = append(listIPSets[listName], ipset.IPSetName)
		}
	}

	for _, l := range cfg.Lists {
		if l.ListName != name {
			continue
		}

		info := ListInfo{Name: l.ListName, IPSets: listIPSets[l.ListName]}
		if info.IPSets == nil {
			info.IPSets = []string{}
		}
		switch {
		case l.URL != "":
			info.Type = "url"
			info.URL = l.URL
		case l.File != "":
			info.Type = "file"
			info.File = l.File
			// Read file contents
			data, err := os.ReadFile(l.File)
			if err == nil {
				info.Entries = parseListEntries(string(data))
			}
		default:
			info.Type = "inline"
			info.Entries = l.Hosts
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(info)
		return
	}

	http.Error(w, "list not found", http.StatusNotFound)
}

func (s *Server) handleCreateList(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name  string `json:"name"`
		URL   string `json:"url"`
		IPSet string `json:"ipset"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	req.URL = strings.TrimSpace(req.URL)
	req.IPSet = strings.TrimSpace(req.IPSet)
	if req.Name == "" {
		http.Error(w, "name is required", http.StatusBadRequest)
		return
	}
	if req.URL == "" {
		http.Error(w, "url is required", http.StatusBadRequest)
		return
	}
	if req.IPSet == "" {
		http.Error(w, "ipset is required", http.StatusBadRequest)
		return
	}

	cfg, err := config.Load(s.configPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	for _, l := range cfg.Lists {
		if l.ListName == req.Name {
			http.Error(w, "list already exists", http.StatusConflict)
			return
		}
	}

	// Find the target ipset and add the list name to it
	ipsetFound := false
	for i, ipset := range cfg.IPSets {
		if ipset.IPSetName == req.IPSet {
			cfg.IPSets[i].Lists = append(cfg.IPSets[i].Lists, req.Name)
			ipsetFound = true
			break
		}
	}
	if !ipsetFound {
		http.Error(w, "ipset not found: "+req.IPSet, http.StatusBadRequest)
		return
	}

	cfg.Lists = append(cfg.Lists, config.List{
		ListName: req.Name,
		URL:      req.URL,
	})

	if err := config.Save(s.configPath, cfg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (s *Server) handleDeleteList(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	cfg, err := config.Load(s.configPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	found := false
	newLists := make([]config.List, 0, len(cfg.Lists))
	for _, l := range cfg.Lists {
		if l.ListName == name {
			found = true
			continue
		}
		newLists = append(newLists, l)
	}
	if !found {
		http.Error(w, "list not found", http.StatusNotFound)
		return
	}

	cfg.Lists = newLists

	// Remove from all ipsets
	for i, ipset := range cfg.IPSets {
		filtered := make([]string, 0, len(ipset.Lists))
		for _, ln := range ipset.Lists {
			if ln != name {
				filtered = append(filtered, ln)
			}
		}
		cfg.IPSets[i].Lists = filtered
	}

	if err := config.Save(s.configPath, cfg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func (s *Server) handlePutList(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	cfg, err := config.Load(s.configPath)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var req struct {
		Entries []string `json:"entries"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	for i, l := range cfg.Lists {
		if l.ListName != name {
			continue
		}

		switch {
		case l.URL != "":
			http.Error(w, "cannot edit URL-based lists", http.StatusBadRequest)
			return
		case l.File != "":
			// Write entries to file
			content := strings.Join(req.Entries, "\n") + "\n"
			if err := os.WriteFile(l.File, []byte(content), 0644); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
		default:
			// Update inline hosts in config
			cfg.Lists[i].Hosts = req.Entries
			if err := config.Save(s.configPath, cfg); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
		return
	}

	http.Error(w, "list not found", http.StatusNotFound)
}

// parseListEntries parses a list file content into entries, skipping comments and empty lines.
func parseListEntries(content string) []string {
	var entries []string
	for _, line := range strings.Split(content, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		entries = append(entries, line)
	}
	return entries
}
