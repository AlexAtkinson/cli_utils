.PHONY: go-build go-install go-uninstall dts-build dts-install dts-uninstall loggerx-build loggerx-install loggerx-uninstall et-build et-install et-uninstall rc-build rc-install rc-uninstall fmt-table-build fmt-table-install fmt-table-uninstall git-create-gist-build git-create-gist-install git-create-gist-uninstall md-copyright-install md-copyright-uninstall md-copyright-self-test fmt-table-self-test uninstall-all

go-build: dts-build loggerx-build et-build rc-build fmt-table-build git-create-gist-build

go-install: dts-install loggerx-install et-install rc-install fmt-table-install git-create-gist-install md-copyright-install

go-uninstall: dts-uninstall loggerx-uninstall et-uninstall rc-uninstall fmt-table-uninstall git-create-gist-uninstall md-copyright-uninstall

dts-build:
	cd utils/dts && go build -o dts ./main.go

dts-install:
	bash utils/dts/install.sh

dts-uninstall:
	bash utils/dts/uninstall.sh

loggerx-build:
	cd utils/loggerx && go build -o loggerx ./main.go

loggerx-install:
	bash utils/loggerx/install.sh

loggerx-uninstall:
	bash utils/loggerx/uninstall.sh

et-build:
	$(MAKE) -C utils/et build

et-install:
	$(MAKE) -C utils/et install

et-uninstall:
	$(MAKE) -C utils/et uninstall

rc-build:
	$(MAKE) -C utils/rc build

rc-install:
	$(MAKE) -C utils/rc install

rc-uninstall:
	$(MAKE) -C utils/rc uninstall

fmt-table-build:
	$(MAKE) -C utils/fmt-table build

fmt-table-install:
	$(MAKE) -C utils/fmt-table install

fmt-table-uninstall:
	$(MAKE) -C utils/fmt-table uninstall

git-create-gist-build:
	$(MAKE) -C utils/git-create-gist build

git-create-gist-install:
	$(MAKE) -C utils/git-create-gist install

git-create-gist-uninstall:
	$(MAKE) -C utils/git-create-gist uninstall

md-copyright-install:
	$(MAKE) -C utils/markdown-copyright-footer install

md-copyright-uninstall:
	$(MAKE) -C utils/markdown-copyright-footer uninstall

md-copyright-self-test:
	$(MAKE) -C utils/markdown-copyright-footer self-test

uninstall-all: go-uninstall

fmt-table-self-test:
	$(MAKE) -C utils/fmt-table self-test
