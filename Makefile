VERSION := $(shell sed -n 's:.*<version>\(.*\)</version>.*:\1:p' SpottyIce/install.xml)

.PHONY: test zip clean

test:
	prove -l t/

zip: test
	rm -f SpottyIce-$(VERSION).zip
	cd SpottyIce && zip -qr ../SpottyIce-$(VERSION).zip . -x '*.DS_Store'
	@echo "Built SpottyIce-$(VERSION).zip"

clean:
	rm -f SpottyIce-*.zip
