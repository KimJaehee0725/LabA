ARG OVERLEAF_IMAGE=sharelatex/sharelatex:5.5.8
FROM ${OVERLEAF_IMAGE}

USER root

ARG TEXLIVE_EXTRA_PACKAGES="latexmk biber biblatex chemfig pgfplots tikz-cd kotex-utf kotex-utils kotex-plain unfonts-core"
ARG TEXLIVE_REPOSITORY="https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/2025/tlnet-final"

RUN if command -v tlmgr >/dev/null 2>&1; then \
      tlmgr option repository "${TEXLIVE_REPOSITORY}"; \
      tlmgr update --self; \
      tlmgr install ${TEXLIVE_EXTRA_PACKAGES}; \
    fi
