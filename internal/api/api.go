package api

import (
	"net/http"
)

type Server struct {
	configPath string
	mux        *http.ServeMux
}

func New(configPath string) *Server {
	s := &Server{
		configPath: configPath,
		mux:        http.NewServeMux(),
	}
	s.routes()
	return s
}

func (s *Server) Handler() http.Handler {
	return s.mux
}

func (s *Server) routes() {
	s.mux.HandleFunc("GET /api/config", s.handleGetConfig)
	s.mux.HandleFunc("PUT /api/config", s.handlePutConfig)
	s.mux.HandleFunc("GET /api/config/raw", s.handleGetConfigRaw)
	s.mux.HandleFunc("PUT /api/config/raw", s.handlePutConfigRaw)
	s.mux.HandleFunc("GET /api/lists", s.handleGetLists)
	s.mux.HandleFunc("GET /api/lists/{name}", s.handleGetList)
	s.mux.HandleFunc("PUT /api/lists/{name}", s.handlePutList)
	s.mux.HandleFunc("POST /api/actions/download", s.handleDownload)
	s.mux.HandleFunc("POST /api/actions/apply", s.handleApply)
	s.mux.HandleFunc("POST /api/actions/self-check", s.handleSelfCheck)
	s.mux.HandleFunc("GET /api/status", s.handleStatus)
}
