ARG OVERLEAF_IMAGE=sharelatex/sharelatex:5.0.8
FROM ${OVERLEAF_IMAGE}

USER root

RUN tlmgr update --self || true; \
    tlmgr install latexmk biber biblatex chemfig pgfplots tikz-cd kotex-utf kotex-utils kotex-plain hcr-lvt unfonts-core || true

USER sharelatex
