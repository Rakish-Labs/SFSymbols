PROJ_DIR := ${CURDIR}

default: generate-symbol

generate-symbol:
	cd SymbolsGenerator && \
	swift run SymbolsGenerator $(PROJ_DIR)/Sources/SFSymbols/Symbols/

.PHONY: generate-symbol
