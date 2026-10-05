FROM mcr.microsoft.com/devcontainers/base:resolute

RUN apt update && apt upgrade -y && apt install -y \
    ffmpeg \
    fonts-noto-cjk \
    fzf \
    libreoffice-impress \
    poppler-utils \
    postgresql-client \
    python3-pip

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash \
    && apt install -y nodejs

RUN corepack enable

RUN pip3 install --break-system-packages "markitdown[pptx]" Pillow

RUN npm install -g \
    @anthropic-ai/claude-code \
    hyperframes

RUN npx --yes playwright@1.63.0 install-deps chromium

USER vscode

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV SHELL=/bin/zsh
ENV PATH=${PATH}:${HOME}/.local/bin

RUN npx --yes playwright@1.63.0 install chromium
