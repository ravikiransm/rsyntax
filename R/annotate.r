#' Annotate a tokenlist based on rsyntax queries
#'
#' Apply queries to extract syntax patterns, and add the results as two columns to a tokenlist.
#' One column contains the ids for each hit. The other column contains the annotations.
#' Only nodes that are given a name in the tquery (using the 'save' parameter) will be added as annotation.
#' 
#' Note that while queries only find 1 node for each saved component of a pattern (e.g., quote queries have 1 node for "source" and 1 node for "quote"), 
#' all children of these nodes can be annotated by settting fill to TRUE. If a child has multiple ancestors, only the most direct ancestors are used (see documentation for the fill argument).
#' 
#' @param tokens  A tokenIndex data.table, or any data.frame coercible with \link{as_tokenindex}.
#' @param queries    A tquery or a list of queries, as created with \link{tquery}. 
#' @param column     The name of the column in which the annotations are added. The unique ids are added as column_id
#' @param as_chain If TRUE, Nodes that have already been assigned assigned earlier in the chain will be ignored (see 'block' argument). 
#' @param block      Optionally, specify ids (doc_id - sentence - token_id triples) that are blocked from querying and filling (ignoring the id and recursive searches through the id). 
#' @param unique_fill If TRUE, only the fill value of the closest parent will be used, and nodes that are already directly matched will not be filled.
#' @param concat_dup If TRUE (default), duplicate values will be concatenated. Otherwise, rows will be duplicated.
#' @param show_fill if TRUE, return column with fill level
#' 
#' @export
annotate <- function(tokens, queries, column, as_chain=T, block=NULL, unique_fill=F, concat_dup=T, show_fill=F) {
  tokens = as_tokenindex(tokens)
  nodes = apply_queries(tokens, queries, as_chain=as_chain, block=block)
  if (nrow(nodes) == 0) {
    message('No nodes found')
    id_column = paste0(column, '_id')
    if (!column %in% colnames(tokens)) tokens[, (column) := character()] else tokens[,(column) := NA]
    if (!id_column %in% colnames(tokens)) tokens[, (id_column) := character()] else tokens[,(id_column) := NA]
    return(tokens)
  }
  annotate_nodes(tokens, nodes, column=column, unique_fill=unique_fill, concat_dup=concat_dup, show_fill=show_fill)
}

#' Annotate a tokenlist based on rsyntaxNodes
#'
#' Use rsyntaxNodes, as created with \link{tquery} and \link{apply_queries}, to annotate a tokenlist.
#' Two columns will be added.
#' One column contains the ids for each hit. The other column contains the annotations.
#' Only nodes that are given a name in the tquery (using the 'save' parameter) will be added as annotation.
#' 
#' @param tokens  A tokenIndex data.table, or any data.frame coercible with \link{as_tokenindex}.
#' @param nodes      A data.table, as created with \link{find_nodes} or \link{apply_queries}. Can be a list of multiple data.tables.
#' @param column     The name of the column in which the annotations are added. The unique ids are added as [column]_id
#' @param unique_fill If TRUE, only the fill value of the closest parent will be used, and nodes that are already directly matched will not be filled.
#' @param concat_dup If TRUE (default), duplicate values will be concatenated. Otherwise, rows will be duplicated.
#' @param show_fill if TRUE, return column with fill level
#'
#' @export
annotate_nodes <- function(tokens, nodes, column, unique_fill=F, concat_dup=T, show_fill=F) {
  tokens = as_tokenindex(tokens)
  if (nrow(nodes) == 0) stop('Cannot annotate nodes, because no nodes are provided')
  if (ncol(nodes) <= 3) stop('Cannot annotate nodes, because no nodes are specified (using the save parameter in find_nodes() or tquery())')
  id_column = paste0(column, '_id')
  if (column %in% colnames(tokens)) tokens[, (column) := NULL]
  if (id_column %in% colnames(tokens)) tokens[, (id_column) := NULL]
  
  if (nrow(nodes) == 0) {
    tokens[,(column) := factor()]
    tokens[,(id_column) := numeric()]
    return(tokens)
  }
  
  .NODES = prepare_nodes(tokens, nodes, unique_fill=unique_fill, concat_dup=concat_dup) 
  data.table::setnames(.NODES, c('.ROLE','.ID'), c(column, id_column))
  if (show_fill) {
    data.table::setnames(.NODES, '.FILL_LEVEL', paste0(column, '_FILL'))
  } else {
    .NODES[, .FILL_LEVEL := NULL]
  }
  
  tokens = merge(tokens, .NODES, by=c('doc_id','sentence','token_id'), all.x=T, allow.cartesian = T)
  if (!is.factor(tokens[[column]])) tokens[[column]] = as.factor(tokens[[column]])
  if (!is.factor(tokens[[id_column]])) tokens[[id_column]] = as.factor(tokens[[id_column]])
  as_tokenindex(tokens)
 
}

#' Transform the nodes to long format and match with token data
#'
#' @param tokens     A tokenIndex data.table, or any data.frame coercible with \link{as_tokenindex}.
#' @param nodes      A data.table, as created with \link{find_nodes} or \link{apply_queries}. Can be a list of multiple data.tables.
#' @param use        Optionally, specify which columns from nodes to add. Other than convenient, this is slighly different 
#'                   from subsetting the columns in 'nodes' beforehand if fill is TRUE. When the children are collected,
#'                   the ids from the not-used columns are still blocked (see 'block')
#' @param token_cols A character vector, specifying which columns from tokens to include in the output
#'
#' @return A data.table with the nodes in long format, and the specified token_cols attached 
#' @export
get_nodes <- function(tokens, nodes, use=NULL, token_cols=c('token'), concat_dup=T) {
  tokens = as_tokenindex(tokens)
  
  missing_col = setdiff(token_cols, colnames(tokens))
  if (length(missing_col) > 0) stop(sprintf('columns specified in token_cols arguments not found: %s', paste(missing_col, collapse=', ')))
  
  .NODES = prepare_nodes(tokens, nodes, unique_fill=T, concat_dup=T) 
  
  out = merge(.NODES, tokens, by=c('doc_id','sentence','token_id'))
  subset(out, select = c('doc_id','sentence','token_id','.ID','.ROLE', token_cols))
}
  

prepare_nodes <- function(tokens, nodes, use=NULL, unique_fill=F, concat_dup=T) {
  .NODES = data.table::copy(nodes)
  if (unique_fill) {
    dup_fill = duplicated(.NODES, by=c('doc_id','sentence','token_id')) & .NODES$.FILL_LEVEL > 0
    .NODES = subset(.NODES, !dup_fill)
  }
  
  still_dup = anyDuplicated(.NODES, by=c('doc_id','sentence','token_id'))
  if (concat_dup && still_dup) {
    .SD=NULL
    .NODES = .NODES[,lapply(.SD, paste, collapse=','), by=eval(c('doc_id','sentence', 'token_id'))]
  }
  data.table::setkeyv(.NODES, c('doc_id','sentence','token_id'))
  if (!is.null(use)) .NODES = subset(.NODES, .ROLE %in% use)
  .NODES
}


rm_duplicates <- function(nodes) {
  dup = duplicated(nodes, by = c('doc_id','sentence','token_id'))
  dup_id = unique(nodes$.ID[dup])
  subset(nodes, !nodes$.ID %in% dup_id)
}
