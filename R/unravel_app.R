
#' @importFrom reactable colDef
#' @importFrom utils getParseData
#' @importFrom ggplot2 is.ggplot
NULL

### Shiny App UI elements -----

#' Creates a summary button
#'
#' @param ns_id the \code{character} namespace id
#' @param inputId the \code{character} id for the button
#' @param lineid the \code{integer} id for the line
#' @param change_type the \code{character} for the change types
#' @param value the starting \code{integer} value for the button (0 by default)
#'
#' @return \code{shiny::tags$button}
#' @noRd
summary_button <- function(ns_id, inputId, lineid, change_type, square_css = "square", value = 0) {
  ns <- shiny::NS(ns_id)
  tags$button(
    id = ns(inputId),
    `lineid` = lineid,
    class = glue::glue("d-flex {change_type}-{square_css} noSelect justify-content-center"),
    style = "color:transparent; cursor:pointer;",
    type = "button", as.character(value)
  )
}

#' A helper function that creates a div for a group item for SortableJS
#'
#' In particular, the unique identifiers make up each item:
#' - Item ID: <id> for group item: data, verb1, verb2, ... verbn.
#' "verbN" is better for uniquely identifying since you can have multiple of same verb
#' - Item Summary ID: <id>-summary-box, <id>-summary-box-row, <id>-summary-box-col
#' - Item Box Type ID: <change>-square
#' - Item Glyph ID: <id>-glyph
#' - Item Toggle ID: <id>-toggle
#' - Item CodeMirror ID: <id>-code_mirror
#'
#' @param line the list containing information about a particular line
#' @param ns_id the character for the Shiny module namespace id
#'
#' @return \code{shiny::div}
#' @noRd
group_item_div <- function(line, ns_id) {
  ns <- shiny::NS(ns_id)
  # line_id is for SortableJS and is just a number of the line
  line_id <- line$lineid
  # preprocess that info ahead of time
  line_code <- line$code
  change_type <- line$change
  row <- line$row
  col <- line$col
  # whereas id is for a readable identifier for JS/jquery/CSS
  id <- paste0("line", line$lineid)
  is_verb_line <- line_id != 1L
  # if the col is empty it means we have a list/vector so let's prep css class name for that
  square_css <- ifelse(nzchar(col), "square", "rect")
  # construct the html for the row/col and summary box
  core_divs <- list(
    # row div
    shiny::div(
      class = "justify-content-center align-self-center",
      shiny::div(
        class = "row",
        style = glue::glue("font-size:{ifelse(identical(square_css, 'square'), '0.8em;', '0em;')}"),
        shiny::HTML("&nbsp;")
      ),
      shiny::div(
        class = glue::glue("{id}-summary-box-row d-flex empty-{square_css} justify-content-center"),
        shiny::div(
          class = glue::glue("{id}-row-content align-self-center"), style = "font-size: 0.8em;",
          # update element
          shiny::HTML(row)
        )
      )
    ),
    # column div + square div
    shiny::div(
      class = "justify-content-center align-self-center",
      shiny::div(
        class = glue::glue("{id}-summary-box-col d-flex justify-content-center align-self-center"),
        shiny::div(
          class = glue::glue("{id}-col-content row"),
          style = glue::glue("font-size:{ifelse(identical(square_css, 'square'), '0.8em;', '0em;')}"),
          # update element
          shiny::HTML(col)
        )
      ),
      # update element (class of square)
      summary_button(ns_id, id, line_id, change_type, square_css)
    )
  )
  disabled <- ifelse(is_verb_line, "", "static")
  core_divs <- append(
    core_divs,
    list(
      # glyphicon
      # add the move icon if it's not the first line, else make it transparent
      shiny::div(
        class = glue::glue("{id}-glyph d-flex justify-content-center align-self-center"),
        shiny::span(class = glue::glue("glyphicon glyphicon-move {disabled}"), style = glue::glue("opacity:{as.integer(is_verb_line)};"))
      ),
      # codemirror empty div above
      shiny::div(
        class = "d-flex justify-content-center align-self-center", style = "padding:0.5em;",
        div(class = "row", style = "font-size: 1em;", shiny::HTML("&nbsp;"))
      ),
      # codemirror div (gets dynamically created); fixedPage keeps the width=100%
      shiny::tags$textarea(
        shiny::HTML(line_code),
        class = "verb",
        id = id,
        lineid = line_id
      )
    )
  )

  if (is_verb_line) {
    core_divs <- append(
      core_divs,
      list(
        # toggle checkbox
        shiny::div(
          style = "opacity:1; padding-right:0.25em;",
          shiny::div(
            class = "d-flex justify-content-center align-self-center",
            shiny::div(style = "font-size: 0.8em;", shiny::HTML("&nbsp;"))
          ),
          # the value of `checked` is not meaningful, the existence of attribute turns on toggle by default
          shiny::tags$label(
            class = "switch",
            shiny::tags$input(
              type = "checkbox",
              class = "slider",
              `toggle-id` = id,
              `line-id` = line_id,
              `checked` = TRUE
            ),
            span(class = "slider round")
          )
        )
      )
    )
  }
  # if it's the data line (first line), disable it for SortableJS so we can't move it
  shiny::div(
    class = glue::glue("d-flex list-group-item {disabled}"), id = id, `data-id` = line_id,
    core_divs
  )
}

#' Helper function to create a group item div for SortableJS
#'
#' @param lines a `list(list(...))` containig information for all of the lines
#' @param ns_id a `character` id for the shiny module namespace
#'
#' @return `shiny::tagList`
#' @noRd
create_group_item_tags <- function(lines, ns_id) {
  ataglist <- lapply(lines, group_item_div, ns_id = ns_id)
  class(ataglist) <- c("shiny.tag.list", "list")
  return(ataglist)
}

# Main UI and Server -----

css_dependencies <- function(name = "Unravel") {
  files <- c(
    "all.min.css",
    "bootstrap.min.css",
    "codemirror.css",
    "bootstrap3.min.css",
    "light.css",
    "style.css"
  )

  htmltools::htmlDependency(
    name,
    version = utils::packageVersion("Unravel"),
    src = "css",
    package = "Unravel",
    stylesheet = files
  )
}

#' Unravel UI
#'
#' @param id A \code{character}
#'
#' @importFrom shiny observe
#' @importFrom shiny observeEvent
#' @importFrom shiny reactive
#' @importFrom shiny reactiveValues
#' @importFrom shiny div
#' @importFrom shiny span
#' @importFrom shiny fluidPage
#' @importFrom shiny shinyApp
#' @importFrom shiny tags
#' @importFrom shiny moduleServer
#' @importFrom shiny renderUI
#' @importFrom shiny onStop
#' @importFrom shiny mainPanel
#' @importFrom shiny navbarPage
#'
#' @return \code{shiny::fixedPage}
#' @noRd
unravelUI <- function(id) {
  package_path <- file.path(system.file(package = "Unravel"))
  package_js <- file.path(package_path, "js")
  # namespace for module
  ns <- shiny::NS(id)
  shiny::fixedPage(
    shiny::tags$body(
      # codemirror stuff
      shiny::includeScript(file.path(package_js, "codemirror.min.js")),
      shiny::includeScript(file.path(package_js, "r.js")),
      # Sortable.js
      shiny::includeScript(file.path(package_js, "Sortable.min.js")),
      # custom js for exploration of code
      shiny::includeScript(file.path(package_js, "explorer.js")),
      # tippy
      shiny::includeScript(file.path(package_js, "popper.min.js")),
      shiny::includeScript(file.path(package_js, "tippy-bundle.min.js")),
      shiny::includeScript(file.path(package_js, "script.js"))
    ),
    # although this is super confusing, `plotOutput` is simply a
    # placeholder Shiny output so we can use it to call `help()` programmatically
    # it's a Shiny output that seems to allow invoking help page
    shiny::plotOutput(ns("fn_help_dummy")),
    shiny::div(
      css_dependencies(),
      id = "code_explorer_container",
      # AYANA.. open help page?
      # since the tabsetPanel below renders before the code overlay, this is a hack
      # that 'hides' the tabbed output by simply shifting the content way below
      # so the user is unaware it even existed; when the html for code_explorer loads
      # we set this height to 100% to bring the tab output back.
      style = "height: 1000px;",
      shiny::htmlOutput(ns("code_explorer"))
    ),
    shiny::tabsetPanel(
      shiny::tabPanel("Table",
        shiny::div(
          style = "width: 100%; height: 1200px; margin: 10px;",
          shiny::verbatimTextOutput(ns("generic_output")),
          reactable::reactableOutput(ns("line_table"))
        )
      ),
      # a pane that includes an interactive diagnoistics table for a dataframe
      shiny::tabPanel("Data Details",
        shiny::div(
          style = "width: 100%; height: 1200px; margin: 10px;",
          reactable::reactableOutput(ns("data_details"))
        )
      ),
      shiny::tabPanel("Help",
        shiny::div(
          style = "width: 100%; height: 1200px; margin: 10px;",
          shiny::htmlOutput(ns("picture"))
        )
      )
    )
  )
}

code_explorer_ui <- function(code_info, id) {
  shiny::tagList(
    shiny::br(),
    shiny::fixedPage(
      id = "simpleList", class = "list-group",
      create_group_item_tags(code_info, id),
      shiny::tags$script("setup_editors();"),
      shiny::tags$script("setup_sortable();"),
      # toggle
      shiny::tags$script("setup_toggles();"),
      shiny::tags$script("setup_box_listeners();"),
      # a hack that makes sure the code explorer loads before the tabs output
      shiny::tags$script("document.getElementById('code_explorer_container').style.height = '100%';")
    ),
    shiny::br(),
    # TODO if we want we could also add prompts to the data change scheme color
    shiny::div(
      class = "d-flex justify-content-center",
      shiny::div(
        class = "d-flex align-self-center", style = "margin-left: 8em;",
        # no change
        div(class = glue::glue("d-flex none-square-key justify-content-center"), style = "cursor: default;"),
        div(
          class = glue::glue("d-flex empty-square justify-content-left align-self-center"),
          style = "padding-left: 1em; font-size: 0.8em; width: 80px;", "No change"
        ),
        # internal
        div(class = glue::glue("d-flex internal-square-key justify-content-center"), style = "cursor: default;"),
        div(
          class = glue::glue("d-flex empty-square justify-content-left align-self-center"),
          style = "padding-left: 1em; font-size: 0.8em; width: 100px;", "Internal change"
        ),
        # visible
        div(class = glue::glue("d-flex visible-square-key justify-content-center"), style = "cursor: default;"),
        div(
          class = glue::glue("d-flex empty-square justify-content-left align-self-center"),
          style = "padding-left: 1em; font-size: 0.8em; width: 100px;", "Visible change"
        ),
        # error
        div(class = glue::glue("d-flex error-square-key justify-content-left"), style = "cursor: default;"),
        div(
          class = glue::glue("d-flex empty-square justify-content-left align-self-center"),
          style = "padding-left: 0.5em; font-size: 0.8em; width: 100px;", "Error"
        ),
      )
    ),
    shiny::br()
  )
}

#' Unravel server
#'
#' @param id the app \code{character} id
#' @param user_code the \code{character} code text
#'
#' @importFrom utils getParseData
#' @import tidylog
#'
#' @return there are no values returned for this module server function
#'
#' @examples
#' \dontrun{
#' unravelServer("unravel", "mtcars %>% select(cyl)")
#' }
#' @noRd
unravelServer <- function(id, user_code = NULL) {
  moduleServer(
    id,
    function(input, output, session) {
      #### Setup variables, UI, and handlers -----

      package_path <- file.path(system.file(package = "Unravel"))
      # package_css <- file.path(package_path, "css")
      package_js <- file.path(package_path, "js")

      # these are reactive values related to current line, code info of all lines, summary prompts, and df outputs
      rv <- reactiveValues()
      rv$current <- 0
      rv$code_info <- NULL
      rv$summaries <- list()
      rv$outputs <- NULL
      rv$generic_output <- NULL
      rv$table_output <- NULL
      # used to trigger output (data.frame/lists)
      rv$callouts <- NULL
      rv$main_callout <- NULL
      # used to trigger the Help page for a function
      rv$fns_help <- NULL
      rv$cur_fns_help <- NULL

      # send signal to JS of the code text to display
      session$sendCustomMessage("set_code", paste0(user_code))

      # listen for JS to tell us code is ready for us to be processed
      observeEvent(input$code_ready, {
        # message("Receiving code from JS: ", input$code_ready)
        # TODO-refactor: process lines function?
        # process lines
        if (!is.null(input$code_ready) && nzchar(input$code_ready)) {
          err <- NULL
          log_code(input$code_ready)
          tryCatch(
            {
              # it could be possible that we receive multiple expressions
              # in this case, we only take the first one for now
              # message(input$code_ready)
              quoted <- rlang::parse_expr(input$code_ready)
              outputs <- get_output_intermediates(quoted)
              # set reactive values
              rv$code_info <- lapply(outputs, function(x) {
                list(
                  lineid = x$line,
                  code = x$code,
                  change = x$change,
                  row = abbrev_num(x$row),
                  col = abbrev_num(x$col),
                  err = x$err,
                  class = class(x$output)
                )
              })
              # TODO-enhance: reset current_code_info via a Reset button
              # store the current code metadata for the UI/logic
              rv$current_code_info <- lapply(outputs, function(x) {
                list(
                  lineid = x$line,
                  code = x$code,
                  change = x$change,
                  row = abbrev_num(x$row),
                  col = abbrev_num(x$col),
                  err = x$err,
                  checked = TRUE,
                  class = class(x$output)
                )
              })
              attr(rv$current_code_info, "order") <- seq_len(length(outputs))
              rv$callouts <- lapply(outputs, function(x) {
                list(lineid = paste0("line", x$line), callouts = x$callouts)
              })
              rv$cur_callouts <- lapply(outputs, function(x) x$callouts)

              # information about the functions used in each line
              # and its respective HTML that will allow user to click on them
              rv$fns_help <- lapply(outputs, function(x) {
                list(lineid = paste0("line", x$line), fns_help = x$fns_help)
              })

              rv$summaries <- lapply(outputs, function(x) {
                if (!is.null(x$err)) {
                  x$summary <- x$err
                }
                list(lineid = paste0("line", x$line), summary = x$summary)
              })
              rv$outputs <- lapply(outputs, function(x) list(lineid = paste0("line", x$line), output = x$output))
              # trigger data frame output of the very last line
              rv$current <- length(rv$outputs)
            },
            error = function(e) {
              err <<- e
            }
          )
        }
      })

      # the observer for the code explorer which will get rendered once we have code information
      output$code_explorer <- renderUI({
        if (!is.null(rv$code_info)) {
          shiny::outputOptions(output, "fn_help_dummy", suspendWhenHidden = FALSE, priority = 10)
          code_explorer_ui(rv$code_info, id)
        }
      })

      output$picture <- renderText({
        c(
          '<img src="',
          "https://64.media.tumblr.com/8b8fe0222a392a39bfe4f0ea4ba0fe80/f3f9e94eb528e89a-63/s1280x1920/0f19ec42de599801507a815005bc51ce5ed064a5.pnj",
          '" width=100%>'
        )
      })

      # list for a trigger message input from JS input so we can send callout info for each line
      # this involves sending the list of callouts for highlighting and a list for the function
      # help trigger from JS -> R (Help menu)
      observeEvent(input$need_callouts, {
        # message("JS is ready for callouts: ", input$need_callouts)
        session$sendCustomMessage("callouts", rv$callouts)
        session$sendCustomMessage("fns_help", rv$fns_help)
        # print(rv$callouts)
      })

      # list for a trigger message input from JS input so we can send summary info for data prompts
      observeEvent(input$need_prompts, {
        # message("JS is ready for prompts: ", input$need_prompts)
        session$sendCustomMessage("prompts", rv$summaries)
      })

      #### Inspection of code and summary handlers

      # list for a click square input from JS to tells us which data to display for a particular line
      observeEvent(input$square, {
        # message("clicked on a square: ", input$square)
        # make sure to only change current if the current code info has the line marked as enabled
        if (!is.null(input$square)) {
          log_event(paste0("viewed summary for line ", input$square))
          rv$current <- input$square
          session$sendCustomMessage("square", input$square)
        }
      })

      observeEvent(input$line, {
        # message("clicked on a line: ", input$line)
        # make sure to only change current if the current code info has the line marked as enabled
        if (!is.null(input$line)) {
          log_event(paste0("clicked line ", input$line))
          rv$current <- input$line
          session$sendCustomMessage("line", input$line)
        }
      })

      #### Output handlers  -----

      # a reactive expression that sets and determines the type of data we render on the UI for code output
      # this could be generic output like vectors and lists, or
      # this could be data.frame / tibble
      data <- reactive({
        value <- as.numeric(rv$current)
        out <- NULL
        if (!is.na(value) && length(rv$outputs) > 0 && value <= length(rv$outputs)) {
          out <- rv$outputs[[value]]$output
          # if it's a data.frame then set the table output reactive value
          if (is.data.frame(out)) {
            # reactable can only efficiently display data of a certain size
            # if we enter into the 100K range, it starts to slow down
            # this is a hack to reduce the amount of total rows displayed for performance
            if (dim(out)[[1]] > 5e5) {
              out <- out[1:5e4, ]
            }
            rv$generic_output <- NULL
            rv$table_output <- out
            rv$main_callout <- rv$cur_callouts[[value]]
          } else {
            # NOTE: we have to set table output to NULL if it's not a data.frame, otherwise it will
            # still appear below a generic output
            rv$table_output <- NULL
            rv$generic_output <- out
          }
        }
        out
      })

      # this is the output for non-dataframe objects like ggplot objects, or vectors and lists
      output$generic_output <- renderPrint({
        generic_output <- data()
        if (!is.null(generic_output) && !is.data.frame(generic_output) && !is.ggplot(generic_output)) {
          return(generic_output)
        }
      })

      # shiny output of reactable for a data.frame / tibble
      output$line_table <- reactable::renderReactable({
        final_data <- data()
        if (is.data.frame(final_data) && !is.null(final_data) && length(final_data) >= 1) {
          # if we have a grouped dataframe, to facilitate understanding let's rearrange columns such that
          # the grouped variables appear to the very left
          common_args <-
            list(
              compact = TRUE,
              highlight = TRUE,
              bordered = TRUE,
              rownames = TRUE,
              defaultPageSize = 5,
              showSortable = TRUE,
              searchable = TRUE
            )
          # apply custom styling for column types and any callout columns
          cols_with_types <- get_common_styles(final_data)
          all_cols <- get_column_css(final_data, rv$main_callout, cols_with_types)
          if (is_grouped_df(final_data)) {
            ngroups_text <- glue::glue("# Groups: [{dplyr::n_groups(final_data)}]")
            return(
              do.call(
                reactable::reactable,
                append(
                  common_args,
                  list(
                    # rearrange the data such that group variables are at the beginning
                    data = dplyr::select(.data = final_data, group_vars(final_data), dplyr::everything()) %>% as.data.frame(),
                    columns = append(
                      # add in the group number
                      list(.rownames = colDef(
                        name = glue::glue("<div class = 'groups'>{ngroups_text}</div>"),
                        html = TRUE,
                        maxWidth = 100)
                      ),
                      all_cols
                    ),
                    theme = reactable::reactableTheme(searchInputStyle = list(width = "100%"))
                  )
                )
              )
            )
          } else {
            rowname_background <- list()
            if (inherits(final_data, "rowwise_df")) {
              rowname_background <- list(`background-color` = "lightblue")
            }
            return(
              do.call(
                reactable::reactable,
                append(
                  common_args,
                  list(
                    data = final_data %>% as.data.frame(),
                    columns = append(
                      list(.rownames = colDef(style = append(list(textAlign = "left"), rowname_background), maxWidth = 80)),
                      all_cols
                    ),
                    theme = reactable::reactableTheme(searchInputStyle = list(width = "100%"))
                  )
                )
              )
            )
          }
        }
      })

      # log a user interacting with a table event
      observeEvent(input$table_focus, {
        log_event(input$table_focus)
      })

      #### Diagnosis handler -----

      # log a user interacting with a table event
      observeEvent(input$data_details_focus, {
        log_event(input$data_details_focus)
      })

      output$data_details <- reactable::renderReactable({
        dat <- data()
        if (!is.null(dat)) {
          get_diagnosis(dat)
        }
      })

      #### Function help handlers -----

      # invoke the help menu for a particular function
      observeEvent(input$fn_help, {
        fn <- input$fn_help
        # get the namespaces for the function
        fn_ns <- getAnywhere(fn)$where
        # since tidylog/Unravel gets loaded as part of this package,
        # filter it out so we can get the dplyr/tidyr namespace
        fn_ns <- Filter(function(ns) !grepl('tidylog|Unravel', ns), fn_ns)
        # grab the most relevant namespace that this
        # function belongs to (first element)
        fn_pkg <- unlist(strsplit(fn_ns[[1]], ":"))
        rv$cur_fns_help <- list(fn = fn, pkg = fn_pkg[[2]])
      })

      output$fn_help_dummy <- renderPlot({
        if (!is.null(rv$cur_fns_help) && length(rv$cur_fns_help$pkg) > 0) {
          # log event of referencing help page for a function
          log_help(
            paste0("Open help for ", paste0(rv$cur_fns_help$fn, ":", rv$cur_fns_help$pkg))
          )
          # print(rv$cur_fns_help)
          help(rv$cur_fns_help$fn, rv$cur_fns_help$pkg) # AYANA: calling help() function!!
        }
      })

      #### Structural edit handlers -----

      # this input even tells us which line to (un)comment
      observeEvent(input$toggle, {
        # message("TOGGLE", input$toggle)
        # this lets us get the boolean value of the toggle from JS side!
        if (isTRUE(input$toggle$checked)) {
          session$sendCustomMessage("toggle", paste0("un-commenting line ", input$toggle$lineid))
          log_event(paste0("toggled on line ", input$toggle$lineid))
        } else {
          session$sendCustomMessage("toggle", paste0("commenting line ", input$toggle$lineid))
          log_event(paste0("toggled off line ", input$toggle$lineid))
        }
        line_id <- as.numeric(input$toggle$lineid)
        checked <- input$toggle$checked

        # set the current order of lines
        order <- attr(rv$current_code_info, "order")
        # update the current code info with the checked flag
        rv$current_code_info <- lapply(rv$current_code_info, function(x) {
          if (x$lineid == line_id) {
            x$checked <- checked
          }
          x
        })
        attr(rv$current_code_info, "order") <- order

        # generate new code info and dataframe outputs
        code_info_outputs <- generate_code_info_outputs(order, rv)
        # quit early when no lines are enabled
        if (is.null(code_info_outputs)) {
          return()
        }

        new_code_info <- code_info_outputs$new_code_info
        outputs <- code_info_outputs$outputs

        # update line information for both R and JS
        update_lines(order, outputs, rv$code_info, new_code_info, rv, session)
      })

      observeEvent(input$reorder, {
        # message("REORDER", input$reorder)
        # this lets us get the boolean value of the toggle from JS side!
        order <- as.numeric(input$reorder)

        log_event(paste0("reordered lines to ", paste0(order, collapse=", ")))

        # set and get the new order from current code stat
        attr(rv$current_code_info, "order") <- order

        # generate new code info and dataframe outputs
        code_info_outputs <- generate_code_info_outputs(order, rv)
        # quit early when no lines are enabled
        if (is.null(code_info_outputs)) {
          return()
        }

        new_code_info <- code_info_outputs$new_code_info
        outputs <- code_info_outputs$outputs

        # update line information for both R and JS
        update_lines(order, outputs, rv$code_info, new_code_info, rv, session)
      })
    }
  )
}
