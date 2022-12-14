
#' @importFrom dplyr is_grouped_df
#' @importFrom dplyr group_vars
NULL

# Unravel a chain -----

#' Given a quoted dplyr chain code, return a list of intermediate expressions.
#' The returned list would include the dataframe name expression.
#'
#' @param dplyr_tree quoted dplyr code
#' @param outputs list
#'
#' @return a list
recurse_dplyr <- function(dplyr_tree, outputs = list()) {
  if (inherits(dplyr_tree, "name")) {
    return(list(dplyr_tree))
  }
  # get the output of the quoted expression so far
  base <- append(list(dplyr_tree), outputs)
  if (length(dplyr_tree) < 2) {
    stop(
      "Error: Detected a verb in pipeline that is not a function call for:<br><pre><code>",
      rlang::expr_deparse(dplyr_tree), "</code></pre>"
    )
  }
  # if there are no pipes, return the tree early
  # this will return just the expression itself for single verb calls
  # (e.g. select(diamonds, carat))
  if (!identical(dplyr_tree[[1]], as.symbol("%>%")) &&
      !identical(dplyr_tree[[1]], as.symbol("+"))) {
    return(list(dplyr_tree))
  }
  return(
    append(recurse_dplyr(dplyr_tree[[2]]), base)
  )
}

# Data Change helpers -----

#' Based on the type of tidyr/dplyr function used, return whether or not
#' the type of change was internal (no visible change), visible, or none.
#'
#' @param verb_name the \code{character} representing the function name
#'
#' @return a character
#'
#' @examples
#' \dontrun{
#' get_change_type("group_by")
#' }
#' @export
get_change_type <- function(verb_name) {
  # rn this is just a fail-safe if we for some reason have not supported the
  # correct change type based on actual data; remove it in the future when we
  # are confident of support.
  internal_verbs <- c(
    "group_by", "rowwise"
  )
  visible_verbs <- c(
    "select", "filter", "mutate", "transmute", "summarise", "summarize",
    "arrange", "rename", "rename_with", "distinct", "spread", "gather",
    "pivot_wider", "pivot_longer",  "distinct", "nest", "unnest"," hoist",
    "unnest_longer", "unnest_wider", "drop_na"
  )
  if (verb_name %in% internal_verbs) {
    return("internal")
  } else if (verb_name %in% visible_verbs) {
    return("visible")
  } else {
    return("none")
  }
}

# helper function to get the type of change from previous and current dataframe
get_data_change_type <- function(verb_name, prev_output, cur_output) {
  # set the change type for summary box
  change_type <- "none"
  # when using `{readr}`, tibbles get a "spec_tbl_df" class attached
  # so we'll just strip it for now to make comparisons work
  prev_classes <- class(prev_output)
  cur_classes <- class(cur_output)
  class(prev_output) <- prev_classes[prev_classes != "spec_tbl_df"]
  class(cur_output) <- cur_classes[cur_classes != "spec_tbl_df"]
  # NOTE: once a data.frame enters the tidyverse pipeline it gets type-casted
  # to a tibble so the check here is to make sure to compare apples to apples or
  # tibble to tibble instead of flagging type change as visible effect; otherwise,
  # just compare outputs normally.
  data_same <-
    if ((!tibble::is_tibble(prev_output) && tibble::is_tibble(cur_output))) {
      identical(tibble::as_tibble(prev_output), cur_output)
    } else {
      identical(prev_output, cur_output)
    }
  prev_rowwise <- inherits(prev_output, "rowwise_df")
  cur_rowwise <- inherits(cur_output, "rowwise_df")
  prev_grouped <- is_grouped_df(prev_output)
  cur_grouped <- is_grouped_df(cur_output)
  if (data_same) {
    change_type <- "none"
  } else {
    change_type <- "visible"
    # check for an internal (invisible) change
    if(!verb_name %in% c("summarize", "summarise")) {
      if (verb_name %in% c("as_tibble", "as.tibble")) {
        change_type <- "internal"
      } else if ((!prev_rowwise && cur_rowwise) || (prev_rowwise && !cur_rowwise)) {
        # rowwise case
        change_type <- "internal"
      } else if(
        (verb_name %in% c("group_by", "ungroup")) &&
        # grouped vs ungrouped or grouped vs grouped case
        ((!prev_grouped && cur_grouped) || (prev_grouped && !cur_grouped) ||
        (prev_grouped && cur_grouped && !identical(group_vars(prev_output), group_vars(cur_output))))
      ) {
        change_type <- "internal"
      }
    }
  }
  return(change_type)
}

# Extract callout words -----

# helper function to add some range info for the callout words
gather_callouts <- function(callouts, deparsed) {
  if (is.null(callouts)) return(NULL)
  # store some info about the range so JS knows which
  code <- trimws(deparsed)
  parse_tree <- getParseData(parse(text = code))
  callout_words <- lapply(callouts, function(x) x$word)
  filtered_tree <- parse_tree[parse_tree$token != 'SYMBOL_FUNCTION_CALL', ]
  filtered_tree <- filtered_tree[filtered_tree$text %in% unlist(callout_words), ]
  # if there is an expression for the arguments where we have the same name of the callout word
  # for both creation of a variable and a symbol within the expression, let's just keep the
  # tree info for the SYMBOL_SUB
  has_multiple_instances <- "SYMBOL_SUB" %in% filtered_tree$token && "SYMBOL" %in% filtered_tree$token
  if (has_multiple_instances) {
    filtered_tree <- filtered_tree[filtered_tree$token == "SYMBOL_SUB", ]
  }
  # grab the col1, col2 and store them as 2 more items in the callouts list
  filtered_callouts <- filtered_tree[
    filtered_tree$text %in% callout_words, c('text', 'line1', 'line2', 'col1', 'col2')
  ]
  if (nrow(filtered_callouts) > 0) {
    # return a list of callouts with the range information baked in for JS to mark
    return(
      list(
        modifyList(
          lapply(
            callouts,
            function(callout) {
              # store the token range info for each callout word instance
              token_info <- filtered_callouts[filtered_callouts$text == callout$word, ]
              callout[['location']] <- list(token_info)
              callout
            }
          ),
          list(callouts)
        )
      )
    )
  }
  # in some cases, we can have changed columns yet they aren't present in the code text
  # if that is the case make sure to return callouts that contain an empty list for callouts
  if (length(callouts) != 0) {
    return(
      list(
        lapply(
          callouts,
          function(callout) {
            callout[['location']] <- list()
            callout
          }
        )
      )
    )
  }
  return(list(callouts))
}

# helper function to add the function name and html info for the function help words
gather_fns_help <- function(fns_help, deparsed) {
  # store some info about the range so JS knows which
  code <- trimws(deparsed)
  parse_tree <- getParseData(parse(text = code))
  fns_help_words <- lapply(fns_help, function(x) x$word)
  # grab the col1, col2, and text
  filtered_tree <- parse_tree[parse_tree$token == 'SYMBOL_FUNCTION_CALL', ]
  filtered_fns_help <- filtered_tree[c('text', 'line1', 'line2', 'col1', 'col2')]
  # if there were any function calls from the parse tree info, then let's
  # construct a function list so we can use it to hyperlink functions on JS side
  if (nrow(filtered_fns_help) > 0) {
    return(
      list(
        lapply(
          filtered_fns_help$text,
          function(fn_name) {
            fn <- list(word = fn_name, html = glue::glue("<a id='{fn_name}' class='fn_help'>{fn_name}</a>"))
            fn
          }
        )
      )
    )
  }
  return(list(fns_help))
}

# Extract intermediates -----

#' Given an expression of fluent code, return a list of intermediate outputs.
#'
#' If there is an error, \code{get_output_intermediates} will return outputs up to that
#' line, with an error message for the subsequent line at fault.
#'
#' @param pipeline an \code{expression}
#'
#' TODO-refactor: make the returned object an R6 class or a structure list so we can have one location
#' for modification
#'
#' @return \code{list(
#'   intermediates = list(tibble),
#'   error = character(),
#' )}
#'
#'
#' @examples
#' \dontrun{
#' require(tidyverse)
#' "diamonds %>%
#'   select(carat, cut, color, clarity, price) %>%
#'   group_by(color) %>%
#'   summarise(n = n(), price = mean(price)) %>%
#'   arrange(desc(color))" -> pipeline
#' quoted <- rlang::parse_expr(pipeline)
#' outputs <- get_output_intermediates(quoted)
#'
#' quoted <- rlang::parse_expr("select(diamonds, carat, cut, color, clarity, price)")
#' outputs <- get_output_intermediates(quoted)
#' }
#' @export
get_output_intermediates <- function(pipeline) {
  clear_verb_summary()
  clear_callouts()
  clear_fns_help()
  old_verb_summary <- ""

  # if code is an assignment expression, grab the value (rhs)
  if (!is.symbol(pipeline) && identical(pipeline[[1]], as.symbol("<-"))) {
    pipeline <- pipeline[[3]]
  }

  # check if only a name has been passed for full expression which is
  # potentially a dataframe
  # AYANA
  if (inherits(pipeline, "name") && is.data.frame(eval(pipeline))) {
    output <- eval(pipeline)
    return(list(
      list(
        line = 1,
        code = rlang::expr_deparse(pipeline),
        change = "none",
        output = output,
        row = dim(output)[[1]],
        col = dim(output)[[2]],
        summary = paste("<strong>Summary:</strong>", tidylog::get_data_summary(output))
      )
    ))
  }

  has_pipes <- identical(pipeline[[1]], as.symbol("%>%")) || identical(pipeline[[1]], as.symbol("+"))
  # check if we have a dataframe as first argument for single verb code
  if (!has_pipes) {
    err <- NULL
    tryCatch({
        output <<- eval(pipeline)
        first_arg_data <<- is.data.frame(output)
      },
      error = function(e) {
        err <<- crayon::strip_style(e$message)
      }
    )
    if (!is.null(err)) {
      return(list(
        list(
          line = 1,
          code = rlang::expr_deparse(pipeline),
          change = "error",
          summary = paste("<strong>Summary:</strong>", err)
        )
      ))
    }
  }
  # if we don't have pipes and we don't have a function that has a first argument as dataframe
  # quit early and surface error, unless it's a ggplot object
  if (!has_pipes && !first_arg_data && !"ggplot" %in% class(output)) {
    # message("`pipeline` input is not a pipe call!")
    return(list(
      list(
        line = 1,
        code = rlang::expr_deparse(pipeline),
        change = "error",
        summary = "<strong>Summary:</strong> Your code does not use functions that take in a dataframe."
      )
    ))
  }

  lines <- NULL
  # first grab all of the lines as a list of of language objects
  # potentially we could error out when trying to recursive invalid pipelines (for e.g. bad order of lines)
  err <- NULL
  tryCatch({
      lines <- recurse_dplyr(pipeline)
    },
    error = function(e) {
      err <<- crayon::strip_style(e$message)
    }
  )
  # if so, just return with error message (currently not being used in front-end)
  if (!is.null(err)) {
    return(err)
  }

  results <- list()
  for (i in seq_len(length(lines))) {
    if (i != 1) {
      verb <- lines[[i]][[3]]
      verb_name <- rlang::expr_deparse(verb[[1]])
    } else if (!has_pipes && first_arg_data) {
      verb <- lines[[i]]
      verb_name <- rlang::expr_deparse(verb[[1]])
    } else {
      verb <- lines[[i]]
      verb_name <- ""
    }

    # AYANA: all of these dataframes can be depricated probably, but just commenting out for now
    # summary_df <- data.frame(
    #   v_name = c("group_by", "summarise"),
    #   v_summary = c("Use <strong>group_by(.data, ???, .add = FALSE, .drop = TRUE)</strong> to create a \"grouped\"
    #                 copy of a table grouped by columns in ... dplyr functions will manipulate
    #                 each \"group\" separately and combine the results.",
    #                 "<strong>summarise(.data, ???)</strong> Compute table of summaries.")
    # )
    
    # related_v1_df <- data.frame(
    #   v_name = c("group_by", "summarise", "mutate", "filter", "rename", "arrange", "select"),
    #   related = c("group_map", "arrange", "arrange", "arrange", "arrange", "filter", "arrange")
    # )
    # related_v2_df <- data.frame(
    #   v_name = c("group_by", "summarise", "mutate", "filter", "rename", "arrange", "select"),
    #   related = c("group_nest", "filter", "filter", "mutate", "filter", "mutate", "filter")
    # )
    # related_v3_df <- data.frame(
    #   v_name = c("group_by", "summarise", "mutate", "filter", "rename", "arrange", "select"),
    #   related = c("group_split", "mutate", "rename", "rename", "mutate", "rename", "mutate")
    # )


    images_df <- data.frame(
      v_name = c("summarise", "select", "mutate", "rename", "add_row", "arrange", "filter", "group_by"),
      links = c("<img src='https://64.media.tumblr.com/69fb544449401e29286709a951499afd/ea825d9d9c2f399b-10/s1280x1920/20cfe00ec4bfc5737c0626283403c7f8a6160fca.pnj' alt='No visual summary available for this function :(', width=100%><br>",
                "<img src='https://64.media.tumblr.com/ae0d444683ec5a910f484e019ca011d8/ea825d9d9c2f399b-12/s1280x1920/421297ce36e2f8f5bc9c5aba7f7f963223d5bbb3.pnj' alt='No visual summary available for this function :(', width=100%><br>",
                "<img src='https://64.media.tumblr.com/edfede85482b78e824032c2cfb8f1e95/ea825d9d9c2f399b-8b/s1280x1920/9b64a0e1a3f549f2c12b435085d07e947485a521.pnj' alt='No visual summary available for this function :(', width=100%><br>",
                "<img src='https://64.media.tumblr.com/d5d9ad830fb9e0060aa25ce19d435c48/ea825d9d9c2f399b-9e/s1280x1920/b41e8a2b53f530e9fc73e1c3a4f73eb7685b771f.pnj' alt='No visual summary available for this function :(', width=100%><br>",
                "<img src='https://64.media.tumblr.com/e6d733852c9fa90901de638ecfcf339b/ea825d9d9c2f399b-fe/s1280x1920/6e939a682bd46eff224b78099182dabd64b4d2a0.pnj' alt='No visual summary available for this function :(', width=100%><br>",
                "<img src='https://64.media.tumblr.com/76098cd20c96df5d8a02fcabb5e03fc3/ea825d9d9c2f399b-06/s1280x1920/de1f199119ee87a51db239e544fd4499d553f545.pnj' alt='No visual summary available for this function :(', width=100%><br>",
                "<img src='https://64.media.tumblr.com/efa8c1bf0070110b46c9571e079c1c7a/ea825d9d9c2f399b-c7/s1280x1920/bfd41b648ae646fc6b55f7b5f132795684fac4d4.pnj' alt='No visual summary available for this function :(', width=100%><br>",
                "<img src='https://64.media.tumblr.com/4ac588467a9cc5162274ccdbdcef0f3b/ea825d9d9c2f399b-22/s1280x1920/7dcf04098983e92e596eb210915e8cced5e51693.pnj' alt='No visual summary available for this function :(', width=100%><br>")
    )

    errorhelp_df <- read.csv("scraper/scraper_results.csv", header = TRUE, sep = ',', quote = '"', dec = '.', fill = TRUE, comment.char = '')
    colnames(errorhelp_df) <- c("idx","verb_name", "result1", "result2","result3","link1","link2","link3")

    related_df <- read.csv("simil_func/similar_v_scrape_edit_NEW.csv", header = TRUE, sep = ';', quote = '"', dec = '.', fill = TRUE, comment.char = '')
    colnames(related_df) <- c("idx", "verb", "html")

    desc_df <- read.csv("simil_func/backup_descriptions.csv", header = TRUE, sep = ';', quote = '"', dec = '.', fill = TRUE, comment.char = '')
    
    colnames(desc_df) <- c("idx", "verb", "desc")

    # get the deparsed character version
    # NOTE: rlang::expr_deparse breaks apart long strings into multiple character vector
    # we collapse it before further processing to avoid extra \t
    deparsed <- paste0(rlang::expr_deparse(verb), collapse = "")
    # append a \t and a pipe character %>% or ggplot + unless it's the last line
    deparsed <- ifelse(i != 1, style_long_line(verb), deparsed)
    # setup the intermediate list with initial information
    intermediate <- list(line = i, code = deparsed, change = get_change_type(verb_name))
    err <- NULL
    tryCatch({
        # store the intermediate output, and set the change type based on difference
        # between previous and current output
        change_type <- "none"
        data_changed <- FALSE
        if (i == 1) {
          intermediate["output"] <- list(eval(lines[[i]]))
          data_changed <- TRUE
        } else if (i > 1) {
          # check if the previous line had an error, and skip evaluation if it does
          if (identical(results[[i - 1]]$change, "error")) {
            intermediate["output"] <- NULL
            intermediate["change"] <- "error"
            # for now, simply point out that the previous lines have an error
            intermediate["summary"] <- "<strong>Summary:</strong> Previous lines have problems!"
            intermediate["fns_help"] <- gather_fns_help(list(), deparsed)
            results <- append(results, list(intermediate))
            next
          }
          prev_output <- results[[i - 1]]["output"][[1]]
          # for the current line, take the previous output and feed it as the `.data`, and the rest of the args
          # NOTE: because we are not evaluating a `lhs %>% rhs()`, and only `rhs()` we miss out on the '.' pronoun
          # so this is a little hack that binds a name "." to the previous output in a new environment
          e <- rlang::new_environment(parent = rlang::current_env())
          e[["."]] <- prev_output
          # `ggplot` breaks the function(.data = ..., ...) formula, and uses some type of operator overloading
          # so we have to evaluate the ggplot to the current line code text instead
          # TODO: this does not yet gather the ggplot to layer yet
          if ("ggplot" %in% class(prev_output)) {
            call_expr_text <- paste0(results[[i - 1]]$code, deparsed)
            cur_output <- eval(parse(text = call_expr_text), envir = e)
          } else {
            # construct a call for the function such that we use the previous output as the input, and rest of the args
            call_expr <- rlang::call2(verb_name, !!!append(list(prev_output), rlang::call_args(verb)))
            # evaluate the final function call expression within the new environment that holds the "pronoun"
            cur_output <- eval(call_expr, envir = e)
          }
          # wrap output as list so it can be stored properly
          intermediate["output"] <- list(cur_output)
          change_type <- get_data_change_type(verb_name, prev_output, cur_output)
          data_changed <- !identical(prev_output, cur_output)
        }

        out <- intermediate["output"][[1]]
        if (i < length(lines)) {
          if ("ggplot" %in% class(out)) {
            intermediate["code"] <- paste0(deparsed, " +")
          } else {
            intermediate["code"] <- paste0(deparsed, " %>%")
          }
        } else {
          intermediate["code"] <- deparsed
        }
        # store the dimensions of dataframe (don't if it was non-dataframe)
        intermediate["row"] <- dim(out)[[1]]
        intermediate["col"] <- dim(out)[[2]]
        # if the data was not a dataframe, grab the length (for now lists/vectors)
        # Note: we will need a different way to support complex types like ggplot2 objects
        if (is.null(intermediate$row) && is.vector(out)) {
          intermediate["row"] <- length(out)
        }

        # store the function summary
        # for single verb code simply get the change type based on verb for now
        if (!has_pipes && first_arg_data) {
          change_type <- get_change_type(verb_name)
        }
        if (verb_name != "") {
          if (!any(related_df$verb == verb_name)) {
            verb_summary <- paste("<code class='code'>", verb_name, "</code><br>This is not a standard dplyr function. Use the following source for help: ",
                                "<a class=\"fn_help\" href='https://dplyr.tidyverse.org/reference/'>Function Reference</a>", sep="")
          } else {
            # AYANA: deprecated
            # v_related1 <-related_v1_df[related_v1_df$v_name == verb_name,]$related
            # v_related2 <-related_v2_df[related_v2_df$v_name == verb_name,]$related
            # v_related3 <-related_v3_df[related_v3_df$v_name == verb_name,]$related

            html <- related_df[related_df$verb == verb_name,]$html

            if (is.element(verb_name,images_df$v_name)) {

              img_related <- images_df[images_df$v_name == verb_name,]$links

            } else {
              
              img_related <- paste("<strong>Description: </strong>", desc_df[desc_df$verb == verb_name,]$desc, "<br>")
            }

            

            verb_summary <- paste("<code class='code'>", verb_name, "</code><br><br>", img_related, html, sep="")

            # AYANA: deprecated, can delete but keeping for now
            # verb_summary <- paste("<code class='code'>", verb_name, "</code><br>",
            #                     img_related, "<br><strong>Related Verbs:</strong><br>",
            #                     "<a class=\"fn_help\" href='https://dplyr.tidyverse.org/reference/",
            #                     v_related1, ".html'>", v_related1, "</a>, ",
            #                     "<a class=\"fn_help\" href='https://dplyr.tidyverse.org/reference/",
            #                     v_related2, ".html'>", v_related2, "</a>, ",
            #                     "<a class=\"fn_help\" href='https://dplyr.tidyverse.org/reference/",
            #                     v_related3, ".html'>", v_related3, "</a>", sep="")
          }

        } else {
          verb_summary <- get_verb_summary()
        }

        if(is.na(intermediate["output"])) {
          change_type <- "error"
          verb_summary <- "This step produced an `NA`."
        }
        # store the final change type
        intermediate["change"] <- change_type

        # gather the callouts to mark text in editor
        # store the column strings so we can highlight them as callouts
        callouts <- get_line_callouts()
        intermediate["callouts"] <- gather_callouts(callouts, deparsed)
        # store the help strings so we can make functions links to Help pages
        fns_help <- get_fns_help()
        intermediate["fns_help"] <- gather_fns_help(fns_help, deparsed)

        # if we have a dataframe %>% verb() expression, the 'dataframe' summary is simply
        # the dataframe/tibble with dimensions reported (we could expand that if we want)
        if ((i == 1 && (has_pipes || first_arg_data)) || is.null(verb_summary)) {
          verb_summary <- tidylog::get_data_summary(out)
          # attempt to produce a hyperlink for any dataset or expression with functions for
          # the first line
          ns_pkgs <- getAnywhere(deparsed)$where
          ns_pkgs_custom <- Filter(function(ns) grepl(".GlobalEnv", ns), ns_pkgs)
          if (length(ns_pkgs) > 0 && length(ns_pkgs_custom) == 0) {
            dataset_link <- list(
              word = deparsed,
              html = glue::glue("<a id='{deparsed}' class='fn_help'>{deparsed}</a>"),
              location = list(data.frame(text = deparsed, line1 = 1, line2 = 1, col1 = 1, col2 = nchar(deparsed)))
            )
            intermediate[["fns_help"]] <- list(append(dataset_link, intermediate[["fns_help"]]))
          }
        }
        # store the final function summary and set it to empty string if we do not yet have
        # a summary support for the function
        intermediate["summary"] <-
          ifelse(
            data_changed || !is.null(verb_summary),
            paste0("<strong>Summary:</strong> ", verb_summary, collapse = ""),
            ""
          )
        old_verb_summary <- verb_summary
      },
      error = function(e) {
        err <<- e
      }
    )
    # if we have an error, strip the crayon formatting and store the error message
    if (!is.null(err)) {
      # Thought: we could make even more readable messages
      # Error: Must group by variables found in `.data`.
      # * Column `colorr` is not found.
      # for e.g. we could replace the `.data` with the actual expression
      intermediate[["change"]] <- "error"
      msg <- ifelse(
        nzchar(err$message),
        crayon::strip_style(err$message),
        crayon::strip_style(paste0(err))
      )
      msg <- gsub("Error:", "<strong>Error:</strong>", msg)
      msg <- ifelse(!grepl("Error:", msg), paste("<strong>Error:</strong>", msg), msg)
      # try to retain the format as much as possible by keeping it as HTML string
      # style back the x's, i's, and *
      msg <- gsub("\nx", "<br><span style='color:red'>x</span>", msg)
      msg <- gsub("\n\u2139", "<br><span style='color:DodgerBlue'>\u2139</span>", msg)
      msg <- gsub("\n\\*", "<br>*", msg)

      # AYANA: Add stack overflow links to error messages if we've scraped
      if (verb_name != "" && any(errorhelp_df$verb_name == verb_name)) {
        res1 = errorhelp_df[errorhelp_df$verb_name == verb_name,]$result1
        res2 = errorhelp_df[errorhelp_df$verb_name == verb_name,]$result2
        res3 = errorhelp_df[errorhelp_df$verb_name == verb_name,]$result3
        link1 = errorhelp_df[errorhelp_df$verb_name == verb_name,]$link1
        link2 = errorhelp_df[errorhelp_df$verb_name == verb_name,]$link2
        link3 = errorhelp_df[errorhelp_df$verb_name == verb_name,]$link3
        msg <- paste(msg, "<br><br><strong>Help related to: </strong><code class='code'>", 
                    verb_name, "</code><br>1. <a class=\"fn_help\" href='",
                    link1, "'>", res1, "</a><br>2. <a class=\"fn_help\" href='",
                    link2, "'>", res2, "</a><br>3. <a class=\"fn_help\" href='",
                    link3, "'>", res3, "</a>", sep="")
      }

      intermediate[["err"]] <- msg
      
      # even though we have an error, include function hyperlinks so user can
      # invesitage how the functions within the expression of the line work
      intermediate["fns_help"] <- gather_fns_help(list(), deparsed)
    }
    results <- append(results, list(intermediate))
  }

  return(results)
}

#' Given an tidyverse code expression, this will return a list of all of the outputs.
#' It calls \code{get_output_intermediates} to return a simpler representation of all
#' of the intermediate outputs. We simply extract the outputs only from the larger
#' intermediate data structure.
#'
#' @param pipeline tidyverse code expression
#'
#' @return a list of outputs corresponding to each verb in tidyverse code
#'
#'
#' @examples
#' \dontrun{
#' require(tidyverse)
#' quoted <- rlang::parse_expr(
#' diamonds %>%
#'   select(carat, cut, color, clarity, price) %>%
#'   group_by(color) %>%
#'   summarise(n = n(), price = mean(price)) %>%
#'   arrange(desc(color))
#' )
#' outputs <- get_chain_outputs(quoted)
#' }
#' @export
get_chain_outputs <- function(pipeline) {
  all_intermediates <- get_output_intermediates(pipeline)
  only_outputs <- list()
  return(
    lapply(all_intermediates, function(intermediate) {
      intermediate$output
    })
  )
}

