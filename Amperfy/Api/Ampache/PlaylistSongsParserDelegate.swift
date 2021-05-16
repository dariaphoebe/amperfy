import Foundation
import UIKit
import CoreData

class PlaylistSongsParserDelegate: SongParserDelegate {

    let playlist: Playlist
    var items: [PlaylistItem]

    init(playlist: Playlist, libraryStorage: LibraryStorage, syncWave: SyncWave) {
        self.playlist = playlist
        self.items = playlist.items
        super.init(libraryStorage: libraryStorage, syncWave: syncWave, parseNotifier: nil)
    }
    
    override func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch(elementName) {
        case "playlisttrack":
            var order = 0
            if let playlistItemOrder = Int(buffer), playlistItemOrder > 0 {
                // Ampache playlist order is one-based -> Amperfy playlist order is zero-based
                order = playlistItemOrder - 1
            }
            var item: PlaylistItem?
            if order < items.count {
                item = items[order]
            } else {
                item = libraryStorage.createPlaylistItem()
                item?.order = order
                playlist.add(item: item!)
            }
            item?.song = songBuffer
        case "root":
            if items.count > parsedCount {
                for i in Array(parsedCount...items.count-1) {
                    libraryStorage.deletePlaylistItem(item: items[i])
                }
            }
        default:
            break
        }
        
        super.parser(parser, didEndElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName)
    }

}
