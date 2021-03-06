import XCTest
import class Foundation.Bundle

import Spanker

public class TestsBase: XCTestCase {
    
    let jsonDocument = "{\"string-property\":\"string-value\",\"int-max-property\":\(UINT32_MAX),\"long-max-property\":\(INT32_MAX),\"boolean-property\":true,\"null-property\":null,\"int-small-property\":1,\"max-price\":10,\"store\":{\"book\":[{\"category\":\"reference\",\"author\":\"Nigel Rees\",\"title\":\"Sayings of the Century\",\"display-price\":8.95},{\"category\":\"fiction\",\"author\":\"Evelyn Waugh\",\"title\":\"Sword of Honour\",\"display-price\":12.99},{\"category\":\"fiction\",\"author\":\"Herman Melville\",\"title\":\"Moby Dick\",\"isbn\":\"0-553-21311-3\",\"display-price\":8.99},{\"category\":\"fiction\",\"author\":\"J. R. R. Tolkien\",\"title\":\"The Lord of the Rings\",\"isbn\":\"0-395-19395-8\",\"display-price\":22.99}],\"bicycle\":{\"foo\":\"baz\",\"escape\":\"Esc\\b\\f\\n\\r\\t\\n\\t\\u002A\",\"color\":\"red\",\"display-price\":19.95,\"foo:bar\":\"fooBar\",\"dot.notation\":\"new\",\"dash-notation\":\"dashes\"}},\"foo\":\"bar\",\"@id\":\"ID\"}"
    
let jsonNumberSeries = #"{"empty":[],"numbers":[1,2,3,4,5,6,7,8,9,10]}"#
    
let jsonTextSeries = #"{"urls":["http://api.worldbank.org/countries/all/?format=json","http://api.worldbank.org/countries/all/?format=json"],"text":["a","b","c","d","e","f"]}"#
    
}
