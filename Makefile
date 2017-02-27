PROJECT_NAME = Racesow
PROJECT_VERSION_MAJOR = 0
PROJECT_VERSION_MINOR = 6
PROJECT_VERSION_PATCH = 2
PROJECT_VERSION_NUMBER = $(PROJECT_VERSION_MAJOR).$(PROJECT_VERSION_MINOR).$(PROJECT_VERSION_PATCH)
SIMPLE_VERSION_NUMBER = $(PROJECT_VERSION_MAJOR)$(PROJECT_VERSION_MINOR)$(PROJECT_VERSION_PATCH)
PROJECT_VERSION_STRING = $(PROJECT_NAME) $(PROJECT_VERSION_NUMBER)

DOC_DIRECTORY = doc
DOXYGEN_FILE = api.dox
RACESOW_DIRECTORY = racesow
GAMETYPE_DIRECTORY = $(RACESOW_DIRECTORY)/progs/gametypes/racesow
SOURCE_DIRECTORY = source
RELEASE_DIRECTORY = $(SOURCE_DIRECTORY)/release/racesow

.PHONY: all doc version gametype data source_i386 source_x64 source_x86 source_x86_64 modules modules_i386 modules_x64 modules_x86 modules_x86_64 install clean

all: modules_x86_64 install

doc:
	cd doc; doxygen $(DOXYGEN_FILE)

version:
	find $(GAMETYPE_DIRECTORY) -name "*.as" \
	-exec sed -i -e 's/@version.*/@version $(PROJECT_VERSION_NUMBER)/' {} \;
	sed -i -e 's/setVersion(.*)/setVersion( "$(PROJECT_VERSION_NUMBER)" )/' \
	$(GAMETYPE_DIRECTORY)/main.as
	sed -i -e 's/\(PROJECT_NUMBER *=\).*/\1 $(PROJECT_VERSION_NUMBER)/' \
	$(DOC_DIRECTORY)/$(DOXYGEN_FILE)

gametype:
	cd $(RACESOW_DIRECTORY); zip -r rs_gametype$(SIMPLE_VERSION_NUMBER)pure progs configs
	mv $(RACESOW_DIRECTORY)/rs_gametype$(SIMPLE_VERSION_NUMBER)pure.zip rs_gametype$(SIMPLE_VERSION_NUMBER)pure.pk3

data:
	cd $(RACESOW_DIRECTORY); zip -r rs_data$(SIMPLE_VERSION_NUMBER)pure gfx huds
	mv $(RACESOW_DIRECTORY)/rs_data$(SIMPLE_VERSION_NUMBER)pure.zip rs_data$(SIMPLE_VERSION_NUMBER)pure.pk3

source_i386:
	cd $(SOURCE_DIRECTORY); make -f Makefile.i386 cgame game ui

source_x64:
	cd $(SOURCE_DIRECTORY); make -f Makefile.x64 cgame game ui

source_x86:
	cd $(SOURCE_DIRECTORY); make -f Makefile.x86 cgame game ui

source_x86_64:
	cd $(SOURCE_DIRECTORY); make -f Makefile.x86_64 cgame game ui

modules:
	printf "/*\n* Racesow manifest\n*/\n{\n\"Version\" \"$(PROJECT_VERSION_NUMBER)\"\n\"Author\" \"Racesow Dev Team\"\n}" > $(RELEASE_DIRECTORY)/manifest.txt
	cd $(RELEASE_DIRECTORY); zip modules_rs_$(SIMPLE_VERSION_NUMBER) manifest.txt *.so *.dll *.dylib
	mv $(RELEASE_DIRECTORY)/modules_rs_$(SIMPLE_VERSION_NUMBER).zip $(RELEASE_DIRECTORY)/modules_rs_$(SIMPLE_VERSION_NUMBER).pk3
	rm $(RELEASE_DIRECTORY)/manifest.txt

modules_i386: source_i386 modules

modules_x64: source_x64 modules

modules_x86: source_x86 modules

modules_x86_64: source_x86_64 modules

install: gametype data
	mv  rs_data$(SIMPLE_VERSION_NUMBER)pure.pk3 rs_gametype$(SIMPLE_VERSION_NUMBER)pure.pk3 $(RELEASE_DIRECTORY)

clean:
	rm -f *pk3
