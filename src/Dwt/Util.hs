{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ViewPatterns #-}

module Dwt.Util (
  listIntersect -- lists

  -- graphs
  , maxNode, dropEdges, negateGraph, compressGraph, joinGraphs

  -- graphs & monads
  , hasLEdgeM
  , gelemMStrErr, gelemM, gelemMSum

  , fr, fromRight, prependCaller, prependCallerSum -- monads
  ) where

import Data.Graph.Inductive
import Dwt.Types
import Data.List (intersect)
import qualified Data.Map as Map
import Control.Monad.Except (MonadError, throwError)
import Control.Lens  ((.~), (%~))

-- == lists
listIntersect [] = []
listIntersect (x:xs) = foldl intersect x xs

-- == graphs
maxNode :: Gr a b -> Node
maxNode = snd . nodeRange
{-# INLINABLE maxNode #-}

dropEdges :: Gr a b -> Gr a b
dropEdges = gmap (\(_,b,c,_) -> ([], b, c, []))

negateGraph :: Gr a b -> Gr a b
negateGraph m = gmap (\(a,b,c,d) -> (negAdj a, -b, c, negAdj d)) m
  where negAdj = map (\(label,n) -> (label,-n))

-- in progress
-- TODO ! fails silently. use Either.
replaceNode :: LNode a -> Gr a b -> Gr a b
replaceNode (adr,_) (match adr -> (Nothing, g)) = g
replaceNode (adr,dat) (match adr -> (Just (a,b,c,d), g)) = (a,b,dat,d) & g

-- make the nodes the least positive integers possible
compressGraph :: DynGraph gr => gr a b -> gr a b
compressGraph g = let ns = nodes g
                      ns' = [1 .. length ns]
                      mp = Map.fromList $ zip ns ns'
                      chNode n = mp Map.! n
                      chAdj (b,n) = (b, mp Map.! n)
  in gmap (\(a,b,lab,d) -> (map chAdj a, chNode b, lab, map chAdj d)) g

joinGraphs :: DynGraph gr => gr a b -> gr a b -> gr a b
joinGraphs g h =
  let gMax = snd $ nodeRange g
      hMin = fst $ nodeRange h
      shift = 1 + gMax - hMin
      shiftAdj = map (\(elab,n) -> (elab,n+shift)) :: Adj b -> Adj b
      h' = gmap (\(ins,n,nlab,outs) ->
            (shiftAdj ins, n+shift, nlab, shiftAdj outs)) h
  in mkGraph (labNodes g ++ labNodes h') (labEdges g ++ labEdges h')

hasLEdgeM :: RSLT -> LEdge RSLTEdge -> Either DwtErr ()
hasLEdgeM g le@(a,b,lab) = if hasLEdge g le then return ()
  else Left (FoundNo, x, "hasLEdgeM.")
  where x = mEdge .~ Just (a,b) $ mEdgeLab .~ Just lab $ noErrOpts

-- | deprecated, but used for Coll constructor
gelemMStrErr :: (MonadError String m, Graph gr) => gr a b -> Node -> m ()
gelemMStrErr g n = if gelem n g then return () 
  else throwError $ "gelemMStrErr: Node " ++ show n ++ " absent."

gelemM :: Graph gr => gr a b -> Node -> Either DwtErr ()
gelemM g n = if gelem n g then return () 
  else Left (FoundNo, mNode .~ Just n $ noErrOpts, "gelemM.")

gelemMSum :: Graph gr => gr a b -> Node -> Either DwtErrSum ()
gelemMSum g n = if gelem n g then return () 
  else Left (FoundNo, [ErrNode n], "gelemM.")

-- == monads
fromRight, fr :: Either a b -> b  -- TODO: doesn't handle the Left case
  -- is therefore different from Data.Either.fromRight
fr = fromRight
fromRight (Right r) = r
fromRight _ = error "fromRight applied to Left"

prependCaller :: String -> Either DwtErr a -> Either DwtErr a
prependCaller name e@(Right _) = e
prependCaller name (Left e) = Left $ errString %~ (name++) $ e

prependCallerSum :: String -> Either DwtErrSum a -> Either DwtErrSum a
prependCallerSum name e@(Right _) = e
prependCallerSum name (Left e) = Left $ errStringSum %~ (name++) $ e


