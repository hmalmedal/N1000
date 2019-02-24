library(tidyverse)
library(desc)
library(fs)
library(glue)
library(lubridate)
library(sf)
library(usethis)

options(crayon.enabled = FALSE)

url <- "https://nedlasting.geonorge.no/geonorge/Basisdata/N1000Kartdata/GML/Basisdata_0000_Norge_25833_N1000Kartdata_GML.zip"
zipfile <- file_temp(ext = ".zip")
gmldir <- file_temp(pattern = "gml")

curl::curl_download(url = url, destfile = zipfile)
utils::unzip(zipfile = zipfile, exdir = gmldir)

gmlfiles <- dir_ls(gmldir, glob = "*.gml")

layers <- map_dfr(gmlfiles,
                  ~st_layers(.) %>%
                    chuck("name") %>%
                    enframe(name = NULL, value = "layer"),
                  .id = "gmlfile")

geometries <- layers %>%
  mutate(geometry = map2(gmlfile,
                         layer,
                         ~read_sf(.x, layer = .y) %>%
                           set_names(str_c) %>%
                           select(-gml_id) %>%
                           mutate_at(vars(ends_with("dato")),
                                     ~na_if(.x, "1000-01-01") %>%
                                       as_date()) %>%
                           mutate_at(vars(contains("kommunenummer")),
                                     ~str_pad(.x, 4, pad = 0)))) %>%
  mutate_at(vars(gmlfile), path_file) %>%
  mutate(objectname = stringi::stri_trans_general(layer, "latin-ascii"))

rdafiles <- dir_ls("data/", glob = "*.rda")
file_delete(rdafiles)

geometries %>%
  select(objectname, geometry) %>%
  pwalk(function(objectname, geometry) {
    assign(objectname, geometry)
    do.call("use_data", list(as.name(objectname)))
  })

datadoc <- geometries %>%
  mutate(format = map(geometry, capture.output)) %>%
  select(layer, gmlfile, objectname, format) %>%
  pmap(function(layer, gmlfile, objectname, format) {
    c(
      str_c("#' @title ", objectname),
      str_c("#' @description ", layer),
      str_c("#' @source `", gmlfile, "`"),
      "#' @author © [Kartverket](https://kartverket.no/)",
      "#' @format",
      "#' ```",
      str_c("#' ", format),
      "#' ```",
      str_c('"', objectname, '"')
    )
  }) %>%
  flatten_chr()

write_lines(datadoc, "R/datadoc.R")

desc_set_version(glue("{year(today())-2000}.{month(today())}.{mday(today())}"))
desc_set(Date = as.character(today()))

devtools::document()
