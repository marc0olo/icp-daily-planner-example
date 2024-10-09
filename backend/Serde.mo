import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

import Types "Types";

// consider using https://github.com/NatLabs/serde
module Serde {

    let partDelimiter = "<<<<<>>>>>";

    public func serializeOnThisDay(data : Types.OnThisDay) : Blob {
        let text = data.title # partDelimiter # data.year # partDelimiter # data.wikiLink;
        Text.encodeUtf8(text);
    };

    public func deserializeOnThisDay(blob : Blob) : ?Types.OnThisDay {
        let text = switch (Text.decodeUtf8(blob)) {
            case (null) { return null };
            case (?t) { t };
        };
        let parts = Iter.toArray(Text.split(text, #text partDelimiter));
        if (Array.size(parts) != 3) {
            return null;
        };
        let title = parts[0];
        let year = parts[1];
        let wikiLink = parts[2];
        ?{ title = title; year = year; wikiLink = wikiLink };
    };
};
