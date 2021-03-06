context("find nodes")

test_that("find_nodes works", {
  library(testthat)
  tokens = as_tokenindex(tokens_dutchquotes)
  
  #dat = find_nodes(tokens, save='id', lemma = 'dat')
  dat = find_nodes(tokens, 
                    tquery(save='id',lemma='dat'))
  
  expect_equal(nrow(dat), 1)
  expect_equal(dat$token_id, 45)
  
  vcs = find_nodes(tokens, 
                    tquery(save='parent', relation='vc'))
  expect_equal(nrow(vcs), 3)
  expect_equal(sort(vcs$token_id), c(7,45,54))

  body = find_nodes(tokens, 
                     tquery(save='id', relation="vc", 
                            children(save='b', relation='body')))
  expect_equal(nrow(body), 2)

  # can we get_children with children?
  children = find_nodes(tokens, 
                         tquery(children(save='child', relation="body",
                                         children(save='grandchild', relation='vc'))))
  expect_equal(nrow(children), 2)
  
  nodes = find_nodes(tokens, 
                      tquery(save='test', relation='su',
                             children(save='child')))

  # get parents
  parents = find_nodes(tokens, 
                        tquery(relation="vc", parents(save='parent', POS = 'verb')))

  
  expect_equal(nrow(parents), 3)
  expect_equal(parents$token_id, c(6,44,53))
  
  # get parents, grandparents, children and grandchildren
  family = find_nodes(tokens, 
                       tquery(relation='vc',
                              parents(save='parent',
                                      parents(save='grandparent')),
                              children(save='child', relation='obj1',
                                       children(save='grandchild', relation='mod'))))
  
  expect_equal(nrow(family), 4)
  expect_equal(family$token_id, c(53,45,51,50))
  
  # test using req for optional arguments
  test_req = tokens_corenlp
  nodes1 = find_nodes(test_req, 
                       tquery(POS = 'VB*', save='verb',
                              children(relation = 'nsubj', save='subject'),
                              children(relation = 'dobj', save='object', req=F)))
  nodes = find_nodes(test_req, 
                       tquery(POS = 'VB*', save='verb',
                              children(relation = 'nsubj', save='subject'),
                              children(relation = 'dobj', save='object', req=T)))
  nodes3 = find_nodes(test_req, 
                       tquery(POS = 'VB*', save='verb',
                              children(relation = 'nsubj', save='subject')))
  expect_equal(unique(nodes1$.ID), unique(nodes3$.ID))
  expect_true(length(unique(nodes$.ID))< length(unique(nodes1$.ID)))
  
  find_nodes(test_req, 
              tquery(POS = 'VB*', save='verb',
                     children(relation = 'nsubj', save='subject'),
                     children(relation = 'dobj', save='object', req=F)))
})
