package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoad(t *testing.T) {
	cfg, err := Load("../../testdata/keen-pbr.conf")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	// General
	if cfg.General.FallbackDNS != "8.8.8.8" {
		t.Errorf("FallbackDNS = %q, want %q", cfg.General.FallbackDNS, "8.8.8.8")
	}
	if !cfg.General.UseKeeneticAPI {
		t.Error("UseKeeneticAPI should be true")
	}

	// IPSets
	if len(cfg.IPSets) != 1 {
		t.Fatalf("len(IPSets) = %d, want 1", len(cfg.IPSets))
	}
	if cfg.IPSets[0].IPSetName != "vpn1" {
		t.Errorf("IPSetName = %q, want %q", cfg.IPSets[0].IPSetName, "vpn1")
	}
	if cfg.IPSets[0].Routing.FWMark != 1001 {
		t.Errorf("FWMark = %d, want 1001", cfg.IPSets[0].Routing.FWMark)
	}

	// Lists
	if len(cfg.Lists) != 2 {
		t.Fatalf("len(Lists) = %d, want 2", len(cfg.Lists))
	}
	if cfg.Lists[0].ListName != "local" {
		t.Errorf("Lists[0].ListName = %q, want %q", cfg.Lists[0].ListName, "local")
	}
	if len(cfg.Lists[0].Hosts) != 2 {
		t.Errorf("len(Lists[0].Hosts) = %d, want 2", len(cfg.Lists[0].Hosts))
	}
}

func TestSaveAndLoad(t *testing.T) {
	// Load original
	cfg, err := Load("../../testdata/keen-pbr.conf")
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	// Save to temp file
	tmpDir := t.TempDir()
	tmpFile := filepath.Join(tmpDir, "test.conf")
	if err := Save(tmpFile, cfg); err != nil {
		t.Fatalf("Save failed: %v", err)
	}

	// Load back
	cfg2, err := Load(tmpFile)
	if err != nil {
		t.Fatalf("Load after save failed: %v", err)
	}

	// Verify round-trip
	if cfg2.General.FallbackDNS != cfg.General.FallbackDNS {
		t.Errorf("Round-trip FallbackDNS mismatch")
	}
	if len(cfg2.IPSets) != len(cfg.IPSets) {
		t.Errorf("Round-trip IPSets count mismatch")
	}
	if len(cfg2.Lists) != len(cfg.Lists) {
		t.Errorf("Round-trip Lists count mismatch")
	}
}

func TestSaveRawValidation(t *testing.T) {
	tmpDir := t.TempDir()
	tmpFile := filepath.Join(tmpDir, "test.conf")

	// Valid TOML
	err := SaveRaw(tmpFile, `[general]
fallback_dns = "8.8.8.8"
`)
	if err != nil {
		t.Errorf("SaveRaw with valid TOML failed: %v", err)
	}

	// Verify the file was written
	data, err := os.ReadFile(tmpFile)
	if err != nil {
		t.Fatalf("ReadFile failed: %v", err)
	}
	if len(data) == 0 {
		t.Error("SaveRaw wrote empty file")
	}

	// Invalid TOML
	err = SaveRaw(tmpFile, `[invalid toml !!!`)
	if err == nil {
		t.Error("SaveRaw with invalid TOML should fail")
	}
}

func TestLoadRaw(t *testing.T) {
	content, err := LoadRaw("../../testdata/keen-pbr.conf")
	if err != nil {
		t.Fatalf("LoadRaw failed: %v", err)
	}
	if len(content) == 0 {
		t.Error("LoadRaw returned empty content")
	}
}
