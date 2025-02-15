#' Concord Within SITC Codes
#'
#' Concords codes within the Standard International Trade Classification classification (SITC Revision 1, 2, 3, 4).
#'
#' @param sourcevar An input character vector of SITC codes. The function accepts 1 to 5-digit SITC codes.
#' @param origin A string setting the input industry classification: "SITC1" (1950), "SITC2" (1974), "SITC3" (1985), "SITC4" (2006).
#' @param destination A string setting the output industry classification: "SITC1" (1950), "SITC2" (1974), "SITC3" (1985), "SITC4" (2006).
#' @param dest.digit An integer indicating the preferred number of digits for output codes. Allows 1 to 5-digit SITC codes. The default is 4 digits.
#' @param all Either TRUE or FALSE. If TRUE, the function will return (1) all matched outputs for each input, and (2) the share of occurrences for each matched output among all matched outputs. Users can use the shares as weights for more precise concordances. If FALSE, the function will only return the matched output with the largest share of occurrences (the mode match). If the mode consists of multiple matches, the function will return the first matched output.
#' @return The matched output(s) for each element of the input vector. Either a list object when all = TRUE or a character vector when all = FALSE.
#' @import tibble tidyr purrr dplyr stringr
#' @importFrom rlang := !! .data
#' @export
#' @source Concordance tables provided by:
#' \itemize{
#'   \item United Nations Trade Statistics <https://unstats.un.org/unsd/trade/classifications/correspondence-tables.asp>
#' }
#' @note Always include leading zeros in codes (e.g., use SITC code 01211 instead of 1211)---results may be buggy otherwise.
#' @examples
#' # SITC4 to SITC3
#' concord_sitc(sourcevar = c("22240", "04110"), origin = "SITC4",
#'              destination = "SITC3", dest.digit = 5, all = TRUE)
#'
#' # SITC1 to SITC4
#' concord_sitc(sourcevar = c("22180", "04100"), origin = "SITC1",
#'              destination = "SITC4", dest.digit = 5, all = TRUE)
concord_sitc <- function (sourcevar,
                          origin,
                          destination,
                          dest.digit = 4,
                          all = FALSE) {

  # load specific conversion dictionary
  if ((origin == "SITC2" & destination == "SITC1") | (origin == "SITC1" & destination == "SITC2")) {

    dictionary <- concordance::sitc2_sitc1

  } else if ((origin == "SITC3" & destination == "SITC1") | (origin == "SITC1" & destination == "SITC3")){

    dictionary <- concordance::sitc3_sitc1

  } else if ((origin == "SITC4" & destination == "SITC1") | (origin == "SITC1" & destination == "SITC4")){

    dictionary <- concordance::sitc4_sitc1

  } else if ((origin == "SITC3" & destination == "SITC2") | (origin == "SITC2" & destination == "SITC3")){

    dictionary <- concordance::sitc3_sitc2

  } else if ((origin == "SITC4" & destination == "SITC2") | (origin == "SITC2" & destination == "SITC4")){

    dictionary <- concordance::sitc4_sitc2

  } else if ((origin == "SITC4" & destination == "SITC3") | (origin == "SITC3" & destination == "SITC4")){

    dictionary <- concordance::sitc4_sitc3

  } else {

    stop("Conversion dictionary not available.")

  }

  # sanity check
  if (length(sourcevar) == 0) {return(character(0))}

  # get the number of unique digits, excluding NAs
  digits <- unique(nchar(sourcevar))
  digits <- digits[!is.na(digits)]

  # check whether input codes have the same digits
  if (length(digits) > 1) {stop("'sourcevar' has codes with different number of digits. Please ensure that input codes are at the same length.")}

  # set acceptable digits for inputs and outputs
  if ((origin == "SITC1" | origin == "SITC2" | origin == "SITC3" | origin == "SITC4") & (destination == "SITC1" | destination == "SITC2" | destination == "SITC3"| destination == "SITC4")){

    origin.digits <- c(1, 2, 3, 4, 5)

    if (!(digits %in% origin.digits)) {stop("'sourcevar' only accepts 1, 2, 3, 4, 5-digit outputs for SITC codes.")}

    destination.digits <- c(1, 2, 3, 4, 5)

    if ((!dest.digit %in% destination.digits)) {stop("'dest.digit' only accepts 1, 2, 3, 4, 5-digit outputs for SITC codes.")}

  } else {

    stop("Concordance not supported.")

  }

  # get column names of dictionary
  origin.codes <- names(dictionary)
  destination.codes <- names(dictionary)

  # allow origin / destination to be entered in any case
  origin.var <- paste(toupper(origin), "_", digits, "d", sep = "")
  destination.var <- paste(toupper(destination), "_", dest.digit, "d", sep = "")

  if (!origin.var %in% origin.codes){stop("Origin code not supported.")}
  if (!destination.var %in% destination.codes){stop("Destination code not supported.")}

  # check if concordance is available for sourcevar
  all.origin.codes <- dictionary %>%
    pull(!!as.name(origin.var))

  if (!all(sourcevar %in% all.origin.codes)){

    no.code <- sourcevar[!sourcevar %in% all.origin.codes]
    no.code <- paste0(no.code, collapse = ", ")

    warning(paste("Matches for ", str_extract(origin, "[^_]+"), " code(s): ", no.code, " not found and returned NA. Please double check input code and classification.\n", sep = ""))

  }

  # match
  matches <- which(all.origin.codes %in% sourcevar)
  dest.var <- dictionary[matches, c(origin.var, destination.var)]

  # calculate weights for matches
  dest.var <- dest.var %>%
    rename(!!origin := 1,
           !!destination := 2) %>%
    # if input is NA then match should be NA
    mutate(!!as.name(destination) := if_else(is.na(!!as.name(origin)), NA_character_, !!as.name(destination))) %>%
    group_by(!!as.name(origin), !!as.name(destination)) %>%
    mutate(n = length(!!as.name(destination)),
           n = ifelse(is.na(!!as.name(destination)), NA, n)) %>%
    distinct() %>%
    filter(!(is.na(n) & sum(!is.na(n)) > 0)) %>%
    group_by(!!as.name(origin)) %>%
    mutate(n_sum = sum(.data$n, na.rm = TRUE),
           weight = .data$n/.data$n_sum) %>%
    arrange(dplyr::desc(.data$weight)) %>%
    ungroup() %>%
    select(-n, -.data$n_sum) %>%
    rename(match = !!as.name(destination))

  # keep info on all matches and weights?
  if (all == TRUE){

    # merge matches/weights according to input
    out.merge <- nest_join(tibble(!!origin := sourcevar),
                           dest.var,
                           by = origin)

    names(out.merge$dest.var) <- sourcevar

    # fill NAs when there is no match
    out <- map(out.merge$dest.var, function(x){

      if(nrow(x) == 0){

        out.sub <- list(match = NA_character_,
                        weight = NA)

      } else {

        out.sub <- list(match = x$match,
                        weight = x$weight)

      }

    })

  } else {

    # keep match with largest weight
    # if multiple matches have the same weights, keep first match
    dest.var.sub <- dest.var %>%
      group_by(!!as.name(origin)) %>%
      slice(1) %>%
      ungroup() %>%
      select(-.data$weight)

    # handle repeated inputs
    out <- dest.var.sub[match(sourcevar, dest.var.sub %>% pull(!!as.name(origin))), "match"] %>%
      pull(match)

  }

  return(out)

}

