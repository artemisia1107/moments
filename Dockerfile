# =======================
# 前端构建阶段（Node + pnpm）
# =======================
FROM node:20.19.1-bookworm AS front
WORKDIR /app

# 安装 pnpm
RUN npm install -g pnpm@10.10.0

# 拷贝依赖清单并安装
COPY front/package.json .
COPY front/pnpm-lock.yaml .
COPY front/pnpm-workspace.yaml .
RUN pnpm install

# 拷贝前端源码并构建
COPY front/. .
RUN pnpm run generate


# =======================
# 后端构建阶段（Golang）
# =======================
FROM golang:1.23.3-alpine AS backend
ARG VERSION=1.0.0
ARG COMMIT_ID=dev
WORKDIR /app

RUN apk add --no-cache build-base tzdata

# 拷贝后端依赖并下载
COPY backend/go.mod .
COPY backend/go.sum .
RUN go mod download

# 拷贝后端源码与前端构建结果
COPY backend/. .
COPY --from=front /app/.output/public /app/public

# 编译 Go 二进制
RUN go build -tags prod \
  -ldflags="-s -w -X main.version=${VERSION} -X main.commitId=${COMMIT_ID}" \
  -o /app/moments


# =======================
# 最终运行阶段（轻量级镜像）
# =======================
FROM alpine
WORKDIR /app

# 安装依赖
RUN apk update --no-cache && apk add --no-cache ca-certificates tzdata

# ✅ 创建数据库目录，防止 SQLite 报错
RUN mkdir -p /app/data


ENV PORT=3000
ENV TZ=Asia/Shanghai

# 拷贝后端可执行文件 + 静态资源
COPY --from=backend /app/moments /app/moments
COPY --from=backend /app/public /app/public

# 设置权限
RUN chmod +x /app/moments

# 暴露端口
EXPOSE 3000

# 启动应用
CMD ["/app/moments"]
