.PHONY: dev build frontend backend clean

FRONTEND_DIR = frontend
BUILD_DIR = dist

dev-backend:
	go run . -config ./testdata/keen-pbr.conf

dev-frontend:
	cd $(FRONTEND_DIR) && bun run dev

frontend:
	cd $(FRONTEND_DIR) && bun run build

backend: frontend
	go build -o $(BUILD_DIR)/keen-pbr-web .

build: backend

clean:
	rm -rf $(BUILD_DIR) $(FRONTEND_DIR)/dist
