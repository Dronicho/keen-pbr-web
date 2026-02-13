package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
)

func main() {
	port := flag.Int("port", 3000, "HTTP server port")
	configPath := flag.String("config", "/opt/etc/keen-pbr/keen-pbr.conf", "path to keen-pbr config")
	flag.Parse()

	_ = configPath // will be used later

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("keen-pbr-web starting on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
