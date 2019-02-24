
<!-- README.md is generated from README.Rmd. Please edit that file -->

# N1000 Kartdata

Kartdata fra [Kartverket](https://kartverket.no/).

``` r
library(N1000)
plot(sf::st_geometry(Kystkontur))
plot(sf::st_geometry(Riksgrense), add = TRUE)
```

<img src="man/figures/README-kart-1.png" width="100%" />
