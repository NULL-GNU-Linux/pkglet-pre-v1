PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
SCRIPT = pl
MESSAGE ?= Improvements
ifndef ECHO
HIT_TOTAL != ${MAKE} ${MAKECMDGOALS} --dry-run ECHO="HIT_MARK" | grep -c "HIT_MARK"
HIT_COUNT = $(eval HIT_N != expr ${HIT_N} + 1)${HIT_N}
ECHO = "[\033[1;32m`expr ${HIT_COUNT} '*' 100 / ${HIT_TOTAL}`%\033[1;0m]"
endif
.PHONY: install uninstall run help
install:
	@echo -e INSTALL $(ECHO) $(SCRIPT) to $(BINDIR)
	@mkdir -p $(BINDIR)
	@install -m 0755 $(SCRIPT) $(BINDIR)/$(SCRIPT)

uninstall:
	@echo -e UNINSTALL $(ECHO) $(SCRIPT) from $(BINDIR)
	@rm -f $(BINDIR)/$(SCRIPT)

commit:
	@echo -e COMMIT $(ECHO) $(MESSAGE)
	@git add .
	@git commit -a -m "$(MESSAGE)"
	@git push

run:
	@echo -e RUN $(ECHO) $(SCRIPT)
	@lua $(SCRIPT)

help:
	@echo -e "Targets:"
	@echo -e "  install    : Install pkglet to BINDIR"
	@echo -e "  uninstall  : Uninstall pkglet"
	@echo -e "  run        : Run pkglet"
	@echo -e "  help       : Show this help\n"
	@echo -e "Variables:"
	@echo -e "  PREFIX     : $(PREFIX)"
	@echo -e "  BINDIR     : $(BINDIR)"
