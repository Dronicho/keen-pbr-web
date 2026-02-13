.PHONY: dev build frontend backend clean build-mipsle build-arm64 build-all

FRONTEND_DIR = frontend
BUILD_DIR = dist
LDFLAGS = -s -w

dev-backend:
	go run . -config ./testdata/keen-pbr.conf

dev-frontend:
	cd $(FRONTEND_DIR) && bun run dev

frontend:
	cd $(FRONTEND_DIR) && bun run build

backend: frontend
	go build -ldflags="$(LDFLAGS)" -o $(BUILD_DIR)/keen-pbr-web .

build: backend

build-mipsle: frontend
	GOOS=linux GOARCH=mipsle GOMIPS=softfloat go build -ldflags="$(LDFLAGS)" -o $(BUILD_DIR)/keen-pbr-web-linux-mipsle .

build-arm64: frontend
	GOOS=linux GOARCH=arm64 go build -ldflags="$(LDFLAGS)" -o $(BUILD_DIR)/keen-pbr-web-linux-arm64 .

build-all: frontend build-mipsle build-arm64

clean:
	rm -rf $(BUILD_DIR) $(FRONTEND_DIR)/dist
