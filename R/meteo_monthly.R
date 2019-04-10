#' Monthly meteorological data
#'
#' Downloading monthly (meteorological) data from SYNOP / KLIMAT / OPAD stations available in the danepubliczne.imgw.pl collection
#'
#' @param rank rank of station ("synop" , "klimat" , "opad")
#' @param year vector of years (np. 1966:2000)
#' @param status leave the columns with measurement or observation statuses (default status = FALSE - i.e. the status columns are deleted)
#' @param coords add coordinates for the station (logical value TRUE or FALSE)
#' @importFrom RCurl getURL
#' @importFrom XML readHTMLTable
#' @importFrom utils download.file unzip read.csv
#' @return
#' @export
#'
#' @examples \dontrun{
#'   monthly <- meteo_monthly(rank = "klimat")
#'   head(monthly)
#' }
#'

meteo_monthly <- function(rank = "synop", year = 1966:2018, status = FALSE, coords = FALSE){

    base_url <- "https://dane.imgw.pl/data/dane_pomiarowo_obserwacyjne/"

    interval <- "miesieczne" # to mozemy ustawic na sztywno
    meta <- meteo_metadane(interval = "miesieczne", rank = rank)

    a <- getURL(paste0(base_url, "dane_meteorologiczne/", interval, "/", rank, "/"),
                ftp.use.epsv = FALSE,
                dirlistonly = TRUE)
    ind <- grep(readHTMLTable(a)[[1]]$Name, pattern = "/")
    catalogs <- as.character(readHTMLTable(a)[[1]]$Name[ind])

    # fragment dla lat (ktore catalogs wymagaja pobrania:
    years_in_catalogs <- strsplit(gsub(x = catalogs, pattern = "/", replacement = ""), split = "_")
    years_in_catalogs <- lapply(years_in_catalogs, function(x) x[1]:x[length(x)])
    ind <- lapply(years_in_catalogs, function(x) sum(x %in% year) > 0)
    catalogs <- catalogs[unlist(ind)] # to sa nasze prawdziwe catalogs do przemielenia

    all_data <- vector("list", length = length(catalogs))

    for (i in seq_along(catalogs)){
      # print(i)
      catalog <- gsub(catalogs[i], pattern = "/", replacement = "")

      if(rank == "synop") {
        address <- paste0(base_url, "dane_meteorologiczne/miesieczne/",
                        rank, "/", catalog, "/", catalog, "_m_s.zip")
      }
      if(rank == "klimat") {
        address <- paste0(base_url, "dane_meteorologiczne/miesieczne/",
                        rank, "/", catalog, "/", catalog, "_m_k.zip")
      }
      if(rank == "opad") {
        address <- paste0(base_url, "dane_meteorologiczne/miesieczne/",
                        rank, "/", catalog, "/", catalog, "_m_o.zip")
      }

      temp <- tempfile()
      temp2 <- tempfile()
      download.file(address, temp)
      unzip(zipfile = temp, exdir = temp2)
      file1 <- paste(temp2, dir(temp2), sep = "/")[1]
      data1 <- read.csv(file1, header = FALSE, stringsAsFactors = FALSE, fileEncoding = "CP1250")
      colnames(data1) <- meta[[1]]$parameters

      file2 <- paste(temp2, dir(temp2), sep = "/")[2]
      data2 <- read.csv(file2, header = FALSE, stringsAsFactors = FALSE, fileEncoding = "CP1250")
      colnames(data2) <- meta[[2]]$parameters

      # usuwa statusy
      if(status == FALSE){
        data1[grep("^Status", colnames(data1))] = NULL
        data2[grep("^Status", colnames(data2))] = NULL
      }

      unlink(c(temp, temp2))
      all_data[[i]] <- merge(data1, data2,
                           by = c("Kod stacji", "Rok", "Miesi\u0105c"),
                           all.x = TRUE)
    }

    all_data <- do.call(rbind, all_data)
    all_data <- all_data[all_data$Rok %in% year, ]

    # dodaje rank
    rank_code <- switch(rank, synop = "SYNOPTYCZNA", klimat = "KLIMATYCZNA", opad = "OPADOWA")
    all_data <- cbind(data.frame(rank_code = rank_code), all_data)

    if (coords){
      # data("stacje_meteo")
      all_data <- merge(stacje_meteo, all_data, by.x = "Kod_stacji", by.y = "Kod stacji", all.y = TRUE)
    }

    return(all_data) # przyciecie tylko do wybranych lat gdyby sie pobralo za duzo
}
meteo_monthly(rank="synop",year=2000)