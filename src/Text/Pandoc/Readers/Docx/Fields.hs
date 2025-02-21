{-# LANGUAGE OverloadedStrings #-}
{- |
   Module      : Text.Pandoc.Readers.Docx.Fields
   Copyright   : Copyright (C) 2014-2020 Jesse Rosenthal
   License     : GNU GPL, version 2 or above

   Maintainer  : Jesse Rosenthal <jrosenthal@jhu.edu>
   Stability   : alpha
   Portability : portable

For parsing Field definitions in instText tags, as described in
ECMA-376-1:2016, §17.16.5 -}

module Text.Pandoc.Readers.Docx.Fields ( FieldInfo(..)
                                       , parseFieldInfo
                                       ) where

import Data.Functor (($>), void)
import qualified Data.Text as T
import Text.Parsec
import Text.Parsec.Text (Parser)

type URL = T.Text
type Anchor = T.Text

data FieldInfo = HyperlinkField URL
                -- The boolean indicates whether the field is a hyperlink.
               | PagerefField Anchor Bool
               | UnknownField
               deriving (Show)

parseFieldInfo :: T.Text -> Either ParseError FieldInfo
parseFieldInfo = parse fieldInfo ""

fieldInfo :: Parser FieldInfo
fieldInfo =
  try (HyperlinkField <$> hyperlink)
  <|>
  try ((uncurry PagerefField) <$> pageref) 
  <|>
  return UnknownField

escapedQuote :: Parser T.Text
escapedQuote = string "\\\"" $> "\\\""

inQuotes :: Parser T.Text
inQuotes =
  try escapedQuote <|> (T.singleton <$> anyChar)

quotedString :: Parser T.Text
quotedString = do
  char '"'
  T.concat <$> manyTill inQuotes (try (char '"'))

unquotedString :: Parser T.Text
unquotedString = T.pack <$> manyTill anyChar (try $ void (lookAhead space) <|> eof)

fieldArgument :: Parser T.Text
fieldArgument = quotedString <|> unquotedString

-- there are other switches, but this is the only one I've seen in the wild so far, so it's the first one I'll implement. See §17.16.5.25
hyperlinkSwitch :: Parser (T.Text, T.Text)
hyperlinkSwitch = do
  sw <- string "\\l"
  spaces
  farg <- fieldArgument
  return (T.pack sw, farg)

hyperlink :: Parser URL
hyperlink = do
  many space
  string "HYPERLINK"
  spaces
  farg <- fieldArgument
  switches <- spaces *> many hyperlinkSwitch
  let url = case switches of
              ("\\l", s) : _ -> farg <> "#" <> s
              _              -> farg
  return url

-- See §17.16.5.45
pagerefSwitch :: Parser (T.Text, T.Text)
pagerefSwitch = do
  sw <- string "\\h"
  spaces
  farg <- fieldArgument
  return (T.pack sw, farg)

pageref :: Parser (Anchor, Bool)
pageref = do
  many space
  string "PAGEREF"
  spaces
  farg <- fieldArgument
  switches <- spaces *> many pagerefSwitch
  let isLink = case switches of
              ("\\h", _) : _ -> True 
              _              -> False
  return (farg, isLink)
