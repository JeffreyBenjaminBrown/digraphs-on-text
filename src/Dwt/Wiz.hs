    {-# LANGUAGE FlexibleContexts #-}
    {-# LANGUAGE ViewPatterns #-}

    module Dwt.Wiz where
    import Data.Graph.Inductive
    import Dwt.Graph
    import Dwt.Show
    import qualified Data.Maybe as Mb

    import Control.Monad (void)
    import Text.Megaparsec
    import Text.Megaparsec.String -- input stream is of type ‘String’
    import qualified Text.Megaparsec.Lexer as L

    import qualified Text.Read as R -- trying not to need

    data Cmd = InsWord | InsTplt | InsRel | Quit deriving (Show, Read)
    type WizState = RSLT

-- Read a command name.
    parseCmd :: Parser Cmd
    parseCmd = sc *> f <* sc where
      f = symbol "iw" *> pure InsWord
          <|> symbol "ir" *> pure InsRel
          <|> symbol "it" *> pure InsTplt
          <|> symbol "q" *> pure Quit

    sc :: Parser ()
    sc = L.space (void spaceChar) lineCmnt blockCmnt
      where lineCmnt  = L.skipLineComment "//"
            blockCmnt = L.skipBlockComment "/*" "*/"
    
    lexeme :: Parser a -> Parser a
    lexeme = L.lexeme sc
    
    symbol :: String -> Parser String
    symbol = L.symbol sc
    
-- IO
    wiz :: WizState -> IO WizState
    wiz g = do
      putStrLn "Go!"
      mbCmd <- parseMaybe parseCmd <$> getLine
      maybe (wiz g) f mbCmd where
        f cmd = case cmd of 
          Quit -> return g
          InsTplt -> tryWizStateIO "Enter a Tplt to add."
                           ((>0) . length . filter (=='_'))
                           insTplt g
          InsWord ->  tryWizStateIO "Enter a Word (any string, really) to add."
                            (const True)
                            insWord g
          InsRel -> do h <- insRelWiz g; wiz h

    tryWizStateIO :: String                   -> (String-> Bool)
          -> (String-> WizState-> WizState) -> WizState -> IO WizState
    tryWizStateIO askUser good change g = do
      putStrLn askUser
      s <- getLine
      case good s of False -> do putStrLn "No seriously!"
                                 tryWizStateIO askUser good change g
                     True -> wiz $ change s g

    getTpltAddrWiz :: RSLT -> IO Node
    getTpltAddrWiz g = do
      putStrLn "Enter the address of a Template."
      s <- getLine
      case (R.readMaybe s :: Maybe Node) of 
        Nothing -> do putStrLn "Not an address!"; getTpltAddrWiz g
        Just n -> case lab g n of 
          Nothing -> do putStrLn "Address absent."; getTpltAddrWiz g
          Just (Tplt _) -> return n
          Just _ -> do putStrLn "Not a template!"; getTpltAddrWiz g

    getMbrListWiz :: RSLT -> IO [Node]
    getMbrListWiz g = do
      putStrLn "Enter member addresses, separated by space."
      mns <- map (\a -> R.readMaybe a :: Maybe Node) <$> words <$> getLine
      case or $ map Mb.isNothing mns of 
        True -> do putStrLn "Not a list of addresses!"; getMbrListWiz g
        False -> let ns = Mb.catMaybes mns in case and $ map (flip gelem g) ns of
          True -> return ns
          False -> do putStrLn "Those are not all in the graph!"; getMbrListWiz g

    insRelWiz :: WizState -> IO WizState
    insRelWiz g = do 
      tn <- getTpltAddrWiz g
      ns <- getMbrListWiz g
      let mbExpr = lab g tn
      case mbExpr of Nothing -> error "By getTpltAddrWiz, this is impossible."
                     Just tplt -> if tpltArity tplt == length ns
                                  then case insRel tn ns g of
                                         Right h -> return h
                                         _ -> error "Impossible, by wizzes."
                                  else do putStrLn "Arity mismatch!"; insRelWiz g
