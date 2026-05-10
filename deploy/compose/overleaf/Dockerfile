ARG OVERLEAF_IMAGE=sharelatex/sharelatex:5.0.8
FROM ${OVERLEAF_IMAGE}

USER root

ARG TEXLIVE_EXTRA_PACKAGES="latexmk biber biblatex chemfig pgfplots tikz-cd kotex-utf kotex-utils kotex-plain hcr-lvt unfonts-core"

RUN if command -v tlmgr >/dev/null 2>&1; then \
      tlmgr update --self || true; \
      tlmgr install ${TEXLIVE_EXTRA_PACKAGES} || true; \
    fi
