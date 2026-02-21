HAILO_CACHE_SO = cache/libhailo_nif.so
HAILO_CACHE_OBJ_DIR = cache/objs

HAILO_DIR = c_src
PRIV_DIR = $(MIX_APP_PATH)/priv
HAILO_SO = $(PRIV_DIR)/libhailo_nif.so

CFLAGS += -fPIC -I$(FINE_INCLUDE_DIR) -fvisibility=hidden -I$(ERTS_INCLUDE_DIR) -Wall -std=c++17
CFLAGS += -Wno-deprecated-declarations

ifdef DEBUG
CFLAGS += -g
else
CFLAGS += -O3
endif

LDFLAGS += -fPIC -shared -lhailort

SOURCES = $(HAILO_DIR)/hailo_nif.cpp
OBJECTS = $(patsubst $(HAILO_DIR)/%.cpp,$(HAILO_CACHE_OBJ_DIR)/%.o,$(SOURCES))

$(HAILO_SO): $(HAILO_CACHE_SO)
	@ mkdir -p $(PRIV_DIR)
	cp -a $(abspath $(HAILO_CACHE_SO)) $(HAILO_SO)

$(HAILO_CACHE_OBJ_DIR)/%.o: $(HAILO_DIR)/%.cpp
	@ mkdir -p $(HAILO_CACHE_OBJ_DIR)
	$(CXX) $(CFLAGS) -c $< -o $@

$(HAILO_CACHE_SO): $(OBJECTS)
	$(CXX) $(OBJECTS) -o $(HAILO_CACHE_SO) $(LDFLAGS)

clean:
	rm -rf cache
