ifneq (true,$(CI))
ifndef SUBMODULE
UPDATE_COMMAND = echo Updating template && git -C $(LIBDIR) pull && \
		 ([ ! -d $(XSLTDIR) ] || git -C $(XSLTDIR) pull)
FETCH_HEAD = $(wildcard $(LIBDIR)/.git/FETCH_HEAD)
else
UPDATE_COMMAND = echo Your template is old, please run `make update`
FETCH_HEAD = $(wildcard .git/modules/$(LIBDIR)/FETCH_HEAD)
endif

NOW = $$(date '+%s')
ifeq (,$(FETCH_HEAD))
UPDATE_NEEDED = false
else
UPDATE_INTERVAL = 1209600 # 2 weeks
UPDATE_NEEDED = $(shell [ $$(($(NOW) - $(call last_modified,$(FETCH_HEAD)))) -gt $(UPDATE_INTERVAL) ] && echo true)
endif

ifeq (true, $(UPDATE_NEEDED))
latest submit:: auto_update
endif

.PHONY: auto_update
.SILENT: auto_update
.IGNORE: auto_update
auto_update:
	$(UPDATE_COMMAND)

.PHONY: update
update:  auto_update
	@[ ! -r circle.yml ] || \
	  echo circle.yml has been replaced by .circleci/config.yml. Please update from $(LIBDIR)/template.
	@for i in Makefile .travis.yml .circleci/config.yml; do \
	  [ -z "$(comm -13 $$i $(LIBDIR)/template/$$i)" ] || \
	    echo $$i is out of date, check against $(LIBDIR)/template/$$i for changes.; \
	done
	@sed -i~ -e 's,-b master https://github.com/martinthomson/i-d-template,-b main https://github.com/martinthomson/i-d-template,' Makefile && \
	  [ `git status --porcelain Makefile | grep '^[A-Z]' | wc -l` -eq 0 ] || git commit -m "Update Makefile" Makefile
	@dotgit=$$(git rev-parse --git-dir); \
	  [ -L "$$dotgit"/hooks/pre-commit ] || \
	    ln -s ../../$(LIBDIR)/pre-commit.sh "$$dotgit"/hooks/pre-commit; \
	  [ -L "$$dotgit"/hooks/pre-push ] || \
	    ln -s ../../$(LIBDIR)/pre-push.sh "$$dotgit"/hooks/pre-push

endif # CI

define regenerate
@set -ex; \
for f in $(1); do \
  if [ -n "$$(git ls-tree -r @ --name-only "$$f")" ]; then \
    amend=--amend; orig=@~; \
    git rm -f "$$f" && \
    git commit -m "Remove old "$$f""; \
  else \
    amend=; orig=@; \
  fi; \
  $(MAKE) -f $(LIBDIR)/setup.mk "$$f"; \
  git add "$$f"; \
  if ! git diff --quiet "$$orig" -- "$$f"; then \
    echo "Updating $$f"; \
    git commit $$amend -m "Automatic update of $$f"; \
  elif [ -n "$$amend" ]; then \
    git reset "$$orig" --hard; \
  fi; \
done
endef

.PHONY: update-readme
update-readme:
	$(call regenerate,README.md)

.PHONY: update-files
update-files:
	$(call regenerate,README.md Makefile .github/CODEOWNERS .note.xml)
	# .gitignore is fiddly and therefore requires special handling
	$(MAKE) -f $(LIBDIR)/setup.mk setup-gitignore
	@if ! git diff --quiet @ .gitignore; then \
	  git add .gitignore; \
	  git commit -m "Automatic update of .gitignore"; \
	fi
