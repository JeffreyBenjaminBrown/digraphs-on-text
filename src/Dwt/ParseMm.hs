-- usually folded
  -- NEXT: nest, many(the function)
  -- uses some functions by Jake Wheat
    -- https://github.com/JakeWheat/intro_to_parsing

-- init
    module Dwt.ParseMm
      ( module Text.Parsec
      , module Text.Parsec.String
      , module Dwt.ParseMm
      ) where
    import Text.Parsec
    import Text.Parsec.String (Parser)

-- simplified parse commands
    parseWithEof :: Parser a -> String -> Either ParseError a
    parseWithEof p = parse (p <* eof) ""

    regularParse :: Parser a -> String -> Either ParseError a
    regularParse p = parse p ""

    parseWithLeftOver :: Parser a -> String -> Either ParseError (a,String)
    parseWithLeftOver p = parse ((,) <$> p <*> leftOver) ""
      where leftOver = manyTill anyToken eof

-- parsers
    mmEscapedChar :: Parser Char
    mmEscapedChar = mmLeftAngle <|> mmNewline <|> mmRightAngle 
        <|> mmCaret <|> mmAmpersand <|> mmApostrophe
      where mmLeftAngle = pure '<' <* string "&lt;"
            mmNewline = pure '\n' <* string "&#xa;"
            mmRightAngle = pure '>' <* string "&gt;"
            mmCaret = pure '^' <* string "&quot;"
            mmAmpersand = pure '&' <* string "&amp;"
            mmApostrophe = pure '\'' <* string "&apos"

    mmNodeText = char '"' *> 
     (many $ mmEscapedChar <|> satisfy (/= '"')) 
     <* char '"'