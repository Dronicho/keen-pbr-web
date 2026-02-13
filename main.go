package main

import (
	"flag"
	"fmt"
	"keen-pbr-web/internal/api"
	"log"
	"net/http"
)

func main() {
	port := flag.Int("port", 3000, "HTTP server port")
	configPath := flag.String("config", "/opt/etc/keen-pbr/keen-pbr.conf", "path to keen-pbr config")
	flag.Parse()

	apiServer := api.New(*configPath)

	mux := http.NewServeMux()
	mux.Handle("/api/", apiServer.Handler())
	mux.Handle("/", staticHandler())

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("keen-pbr-web listening on %s (config: %s)", addr, *configPath)
	log.Fatal(http.ListenAndServe(addr, mux))
}
