
#' Create a query for dependency based parse trees in a data.table (CoNLL-U or similar format).
#'
#' @description
#' To find nodes you can use named arguments, where the names are column names (in the data.table on which the
#' queries will be used) and the values are vectors with lookup values. 
#' 
#' Children or parents of nodes can be queried by passing the \link{childen} or \link{parents} function as (named or unnamed) arguments.
#' These functions use the same query format as the tquery function, and children and parents can be nested recursively to find children of children etc. 
#' 
#' Please look at the examples below for a recommended syntactic style for using the find_nodes function and these nested functions.
#'
#' @param ...     Accepts two types of arguments: name-value pairs for finding nodes (i.e. rows), and functions to look for parents/children of these nodes.
#'                
#'                The name in the name-value pairs need to match a column in the data.table, and the value needs to be a vector of the same data type as the column.
#'                By default, search uses case sensitive matching, with the option of using common wildcards (* for any number of characters, and ? for a single character).
#'                Alternatively, flags can be used to to change this behavior to 'fixed' (__F), 'igoring case' (__I) or 'regex' (__R). See details for more information. 
#'                
#'                If multiple name-value pairs are given, they are considered as AND statements, but see details for syntax on using OR statements, and combinations.
#'                
#'                To look for parents and children of the nodes that are found, you can use the \link{parents} and \link{children} functions as (named or unnamed) arguments. 
#'                These functions have the same query arguments as tquery, but with some additional arguments. 
#' @param g_id    Find nodes by global id, which is the combination of the doc_id, sentence and token_id. Passed as a data.frame or data.table with 3 columns: (1) doc_id, (2) sentence and (3) token_id. 
#' @param save    A character vector, specifying the column name under which the selected tokens are returned. 
#'                If NA, the column is not returned.
#'                
#'                
#' @return        A tQuery object, that can be used with the \link{apply_queries} function.
#' 
#' @details 
#' There are several flags that can be used to change search condition. To specify flags, add a double underscore and the flag character to the name in the name value pairs (...).
#' If the name is given the suffix __N, only rows without an exact match are found. (so, lemma__N = "fish" look for all rows in which the lemma is not "fish").
#' By adding the suffix __R, query terms are considered to be regular expressions, and the suffix __I uses case insensitive search (for normal or regex search).
#' If the suffix __F is used, only exact matches are valid (case sensitive, and no wildcards).
#' Multiple flags can be combined, such as lemma__NRI, or lemma_IRN  (order of flags is irrelevant)
#' 
#' @examples
#' ## it is convenient to first prepare vectors with relevant words/pos-tags/relations
#' .SAY_VERBS = c("tell", "show","say", "speak") ## etc.
#' .QUOTE_RELS=  c("ccomp", "dep", "parataxis", "dobj", "nsubjpass", "advcl")
#' .SUBJECT_RELS = c('su', 'nsubj', 'agent', 'nmod:agent') 
#' 
#' quotes_direct = tquery(lemma = .SAY_VERBS,
#'                          children(save = 'source', p_rel = .SUBJECT_RELS),
#'                          children(save = 'quote', p_rel = .QUOTE_RELS))
#' quotes_direct ## print shows tquery
#' @export
tquery <- function(..., g_id=NULL, save=NA) {
  #select = deparse(bquote_s(substitute(select), where = parent.frame()))
  l = list(...)
  if (length(l) > 0) {
    is_nested = sapply(l, is, 'tQueryParent') | sapply(l, is, 'tQueryChild') | sapply(l, is, 'tQueryFill') 
    for (fill_i in which(sapply(l, is, 'tQueryFill'))) {
      if (!is.na(save)) {
        l[[fill_i]]$save = paste(save, 'FILL', sep='_')
      } else {
        is_nested = is_nested[-fill_i]
        l = l[-fill_i]
      }
    }
    q = list(g_id=g_id, save=save, lookup = l[!is_nested], nested=l[is_nested])
  } else {
    q = list(g_id=g_id, save=save, lookup =NULL, nested=NULL)
  }
  #check_duplicate_names(q)
  class(q) = c('tQuery', class(q))
  q
}


check_duplicate_names <- function(tq, save_names=c()) {
  if (!is.na(tq$save)) save_names = c(save_names, tq$save)
  if (anyDuplicated(save_names)) stop('tquery cannot contain duplicate "save" values')
  for (n in tq$nested) check_duplicate_names(n, save_names)
}

#' Search for parents or children in tquery
#'
#' Should only be used inside of the \link{tquery} function.
#' Enables searching for parents or children, either direct (depth = 1) or until a given depth (depth 2 for children and grandchildren, Inf (infinite) for all).
#' 
#' Searching for parents/children within find_nodes works as an AND condition: if it is used, the node must have these parents/children.
#' The save argument is used to remember the global token ids (.G_ID) of the parents/children under a given column name.
#' 
#' the not_children and not_parents functions will make the matched children/parents a NOT condition. 
#' 
#' The fill() function is used to include the children of a 'saved' node. It can only be nested in a query if the save argument is not NULL,
#' and by default will include all children of the node.
#'   
#' @param ...     Accepts two types of arguments: name-value pairs for finding nodes (i.e. rows), and functions to look for parents/children of these nodes.
#'                
#'                The name in the name-value pairs need to match a column in the data.table, and the value needs to be a vector of the same data type as the column.
#'                By default, search uses case sensitive matching, with the option of using common wildcards (* for any number of characters, and ? for a single character).
#'                Alternatively, flags can be used to to change this behavior to 'fixed' (__F), 'igoring case' (__I) or 'regex' (__R). See details for more information. 
#'                
#'                If multiple name-value pairs are given, they are considered as AND statements, but see details for syntax on using OR statements, and combinations.
#'                
#'                To look for parents and children of the nodes that are found, you can use the \link{parents} and \link{children} functions as (named or unnamed) arguments. 
#'                These functions have the same query arguments as tquery, but with some additional arguments. 
#' @param g_id    Find nodes by global id, which is the combination of the doc_id, sentence and token_id. Passed as a data.frame or data.table with 3 columns: (1) doc_id, (2) sentence and (3) token_id. 
#' @param save    A character vector, specifying the column name under which the selected tokens are returned. 
#'                If NA, the column is not returned.
#' @param req     Can be set to false to not make a node 'required'. This can be used to include optional nodes in queries. For instance, in a query for finding subject - verb - object triples, 
#'                make the object optional.
#' @param depth   A positive integer, determining how deep parents/children are sought. The default, 1, 
#'                means that only direct parents and children of the node are retrieved. 2 means children and grandchildren, etc.
#'                All parents/children must meet the filtering conditions (... or g_id)
#' @param connected controlls behaviour if depth > 1 and filters are used. If FALSE (default) all parents/children to the given depth are retrieved, and then filtered. 
#'                  This way, grandchilden that satisfy the filter conditions are retrieved even if their parents do not satisfy the conditions.
#'                  If TRUE, the filter is applied at each level of depth, so that only fully connected branches of nodes that satisfy the conditions are retrieved. 
#'
#' @details 
#' Having nested queries can be confusing, so we tried to develop the find_nodes function and the accompanying functions in a way
#' that clearly shows the different levels. As shown in the examples, the idea is that each line is a node, and to look for parents
#' or children, we put them on the next line with indentation (in RStudio, it should automatically allign correctly when you press enter inside
#' of the children() or parents() functions). 
#' 
#' There are several flags that can be used to change search condition. To specify flags, add a double underscore and the flag character to the name in the name value pairs (...).
#' If the name is given the suffix __N, only rows without an exact match are found. (so, lemma__N = "fish" look for all rows in which the lemma is not "fish").
#' By adding the suffix __R, query terms are considered to be regular expressions, and the suffix __I uses case insensitive search (for normal or regex search).
#' If the suffix __F is used, only exact matches are valid (case sensitive, and no wildcards).
#' Multiple flags can be combined, such as lemma__NRI, or lemma_IRN  (order of flags is irrelevant)
#' 
#' @return Should not be used outside of \link{find_nodes}
#' @name nested_nodes
#' @rdname nested_nodes
NULL

#' @rdname nested_nodes
#' @export
children <- function(..., g_id=NULL, save=NA, req=T, depth=1, connected=F) {
  NOT = F
  if (NOT && !req) stop('cannot combine NOT=T and req=F')
  
  #select = deparse(bquote_s(substitute(select)))
  l = list(...)
  if (length(l) > 0) {
    is_nested = sapply(l, is, 'tQueryParent') | sapply(l, is, 'tQueryChild')  | sapply(l, is, 'tQueryFill') 
    for (fill_i in which(sapply(l, is, 'tQueryFill'))) {
      if (!is.na(save)) {
        l[[fill_i]]$save = paste(save, 'FILL', sep='_')
      } else {
        is_nested = is_nested[-fill_i]
        l = l[-fill_i]
      }
    }
    q = list(g_id=g_id, save=save, lookup = l[!is_nested], nested=l[is_nested], level = 'children', req=req, NOT=NOT, depth=depth, connected=connected)
  } else {
    q = list(g_id=g_id, save=save, lookup =NULL, nested=NULL, level = 'children', req=req, NOT=NOT, depth=depth, connected=connected)
  }
  
  
  class(q) = c('tQueryChild', class(q))
  q
}


#' @rdname nested_nodes
#' @export
not_children <- function(..., g_id=NULL, depth=1, connected=F) {
  save=NA
  req = T
  NOT = T
  if (NOT && !req) stop('cannot combine NOT=T and req=F')
  #select = deparse(bquote_s(substitute(select)))
  l = list(...)
  if (length(l) > 0) {
    is_nested = sapply(l, is, 'tQueryParent') | sapply(l, is, 'tQueryChild')  | sapply(l, is, 'tQueryFill')
    if (any(sapply(l, is, 'tQueryFill'))) stop('fill() cannot be used in not_ queries (not_children, not_parents)')
    q = list(g_id=g_id, save=save, lookup = l[!is_nested], nested=l[is_nested], level = 'children', req=req, NOT=NOT, depth=depth, connected=connected)
  } else {
    q = list(g_id=g_id, save=save, lookup =NULL, nested=NULL, level = 'children', req=req, NOT=NOT, depth=depth, connected=connected)
  }
  
  
  class(q) = c('tQueryChild', class(q))
  q
}


#' @rdname nested_nodes
#' @export
parents <- function(..., g_id=NULL, save=NA, req=T, depth=1, connected=F) {
  NOT = F
  if (NOT && !req) stop('cannot combine NOT=T and req=F')
  
  #select = deparse(bquote_s(substitute(select)))
  l = list(...)
  if (length(l) > 0) {
    is_nested = sapply(l, is, 'tQueryParent') | sapply(l, is, 'tQueryChild')  | sapply(l, is, 'tQueryFill')
    for (fill_i in which(sapply(l, is, 'tQueryFill'))) {
      if (!is.na(save)) {
        l[[fill_i]]$save = paste(save, 'FILL', sep='_')
      } else {
        is_nested = is_nested[-fill_i]
        l = l[-fill_i]
      }
    }
    q = list(g_id=g_id, save=save, lookup = l[!is_nested], nested=l[is_nested], level = 'parents', req=req, NOT=NOT, depth=depth, connected=connected)
  } else {
    q = list(g_id=g_id, save=save, lookup =NULL, nested=NULL, level = 'parents', req=req, NOT=NOT, depth=depth, connected=connected)
  }
  
  class(q) = c('tQueryParent', class(q))
  q
}

#' @rdname nested_nodes
#' @export
not_parents <- function(..., g_id=NULL, depth=1, connected=F) {
  save=NA
  req = T
  NOT = T
  if (NOT && !req) stop('cannot combine NOT=T and req=F')
  
  #select = deparse(bquote_s(substitute(select)))
  l = list(...)
  if (length(l) > 0) {
    is_nested = sapply(l, is, 'tQueryParent') | sapply(l, is, 'tQueryChild')  | sapply(l, is, 'tQueryFill')
    if (any(sapply(l, is, 'tQueryFill'))) stop('fill() cannot be used in not_ queries (not_children, not_parents)')
    q = list(g_id=g_id, save=save, lookup = l[!is_nested], nested=l[is_nested], level = 'parents', req=req, NOT=NOT, depth=depth, connected=connected)
  } else {
    q = list(g_id=g_id, save=save, lookup =NULL, nested=NULL, level = 'parents', req=req, NOT=NOT, depth=depth, connected=connected)
  }
  
  class(q) = c('tQueryParent', class(q))
  q
}


#' @rdname nested_nodes
#' @export
fill <- function(..., g_id=NULL, depth=Inf, connected=F) {
  #select = deparse(bquote_s(substitute(select)))
  l = list(...)
  if (length(l) > 0) {
    is_nested = sapply(l, is, 'tQueryParent') | sapply(l, is, 'tQueryChild')  | sapply(l, is, 'tQueryFill')
    if (any(is_nested)) stop('Cannot use nested queries (children(), parents(), etc.) in fill()')
    q = list(g_id=g_id, save='fill', lookup = l[!is_nested], nested=l[is_nested], level = 'children', req=F, NOT=F, depth=depth, connected=connected)
  } else {
    q = list(g_id=g_id, save='fill', lookup =NULL, nested=NULL, level = 'children', req=F, NOT=F, depth=depth, connected=connected)
  }
  
  
  class(q) = c('tQueryFill', class(q))
  q
}



