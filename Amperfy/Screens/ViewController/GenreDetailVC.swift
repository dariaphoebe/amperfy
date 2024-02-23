//
//  GenreDetailVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import CoreData
import AmperfyKit
import PromiseKit

class GenreDetailVC: MultiSourceTableViewController {

    var genre: Genre!
    private var artistsFetchedResultsController: GenreArtistsFetchedResultsController!
    private var albumsFetchedResultsController: GenreAlbumsFetchedResultsController!
    private var songsFetchedResultsController: GenreSongsFetchedResultsController!
    private var optionsButton: UIBarButtonItem!
    private var detailOperationsView: GenericDetailTableHeader?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate.userStatistics.visited(.genreDetail)
        
        artistsFetchedResultsController = GenreArtistsFetchedResultsController(for: genre, coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
        artistsFetchedResultsController.delegate = self
        albumsFetchedResultsController = GenreAlbumsFetchedResultsController(for: genre, coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
        albumsFetchedResultsController.delegate = self
        songsFetchedResultsController = GenreSongsFetchedResultsController(for: genre, coreDataCompanion: appDelegate.storage.main, isGroupedInAlphabeticSections: false)
        songsFetchedResultsController.delegate = self
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.register(nibName: GenericTableCell.typeName)
        tableView.register(nibName: SongTableCell.typeName)
        
        configureSearchController(placeholder: "Artists, Albums and Songs", scopeButtonTitles: ["All", "Cached"])
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenericDetailTableHeader.frameHeight + LibraryElementDetailTableHeaderView.frameHeight))
        if let genericDetailTableHeaderView = ViewBuilder<GenericDetailTableHeader>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: GenericDetailTableHeader.frameHeight)) {
            genericDetailTableHeaderView.prepare(toWorkOn: genre, rootView: self)
            tableView.tableHeaderView?.addSubview(genericDetailTableHeaderView)
            detailOperationsView = genericDetailTableHeaderView
        }
        if let libraryElementDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: GenericDetailTableHeader.frameHeight, width: view.bounds.size.width, height: LibraryElementDetailTableHeaderView.frameHeight)) {
            libraryElementDetailTableHeaderView.prepare(
                playContextCb: {() in PlayContext(containable: self.genre, playables: self.songsFetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.storage.settings.isOfflineMode) ?? [])},
                with: appDelegate.player)
            tableView.tableHeaderView?.addSubview(libraryElementDetailTableHeaderView)
        }
        
        optionsButton = UIBarButtonItem(image: UIImage.ellipsis, style: .plain, target: nil, action: nil)
        optionsButton.menu = UIMenu.lazyMenu {
            EntityPreviewActionBuilder(container: self.genre, on: self).createMenu()
        }
        navigationItem.rightBarButtonItem = optionsButton
        
        containableAtIndexPathCallback = { (indexPath) in
            switch indexPath.section+1 {
            case LibraryElement.Artist.rawValue:
                return self.artistsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case LibraryElement.Album.rawValue:
                return self.albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            case LibraryElement.Song.rawValue:
                return self.songsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            default:
                return nil
            }
        }
        playContextAtIndexPathCallback = { (indexPath) in
            switch indexPath.section+1 {
            case LibraryElement.Artist.rawValue:
                let entity =  self.artistsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                return PlayContext(containable: entity)
            case LibraryElement.Album.rawValue:
                let entity =  self.albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                return PlayContext(containable: entity)
            case LibraryElement.Song.rawValue:
                let entity =  self.songsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                return PlayContext(containable: entity)
            default:
                return nil
            }
        }
        swipeCallback = { (indexPath, completionHandler) in
            switch indexPath.section+1 {
            case LibraryElement.Artist.rawValue:
                let artist = self.artistsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                firstly {
                    artist.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                }.catch { error in
                    self.appDelegate.eventLogger.report(topic: "Artist Sync", error: error)
                }.finally {
                    completionHandler(SwipeActionContext(containable: artist))
                }
            case LibraryElement.Album.rawValue:
                let album = self.albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
                firstly {
                    album.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
                }.catch { error in
                    self.appDelegate.eventLogger.report(topic: "Album Sync", error: error)
                }.finally {
                    completionHandler(SwipeActionContext(containable: album))
                }
            case LibraryElement.Song.rawValue:
                let songIndexPath = IndexPath(row: indexPath.row, section: 0)
                let song = self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
                let playContext = self.convertIndexPathToPlayContext(songIndexPath: songIndexPath)
                completionHandler(SwipeActionContext(containable: song, playContext: playContext))
            default:
                completionHandler(nil)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        artistsFetchedResultsController?.delegate = self
        albumsFetchedResultsController?.delegate = self
        songsFetchedResultsController?.delegate = self
        
        firstly {
            genre.fetch(storage: self.appDelegate.storage, librarySyncer: self.appDelegate.librarySyncer, playableDownloadManager: self.appDelegate.playableDownloadManager)
        }.catch { error in
            self.appDelegate.eventLogger.report(topic: "Genre Sync", error: error)
        }.finally {
            self.detailOperationsView?.refresh()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        artistsFetchedResultsController?.delegate = nil
        albumsFetchedResultsController?.delegate = nil
        songsFetchedResultsController?.delegate = nil
    }
    
    func convertIndexPathToPlayContext(songIndexPath: IndexPath) -> PlayContext? {
        guard let songs = self.songsFetchedResultsController.getContextSongs(onlyCachedSongs: self.appDelegate.storage.settings.isOfflineMode)
        else { return nil }
        let selectedSong = self.songsFetchedResultsController.getWrappedEntity(at: songIndexPath)
        guard let playContextIndex = songs.firstIndex(of: selectedSong) else { return nil }
        return PlayContext(containable: genre, index: playContextIndex, playables: songs)
    }
    
    func convertCellViewToPlayContext(cell: UITableViewCell) -> PlayContext? {
        guard let indexPath = tableView.indexPath(for: cell),
              indexPath.section+1 == LibraryElement.Song.rawValue
        else { return nil }
        return convertIndexPathToPlayContext(songIndexPath: IndexPath(row: indexPath.row, section: 0))
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section+1 {
        case LibraryElement.Artist.rawValue:
            return "Artists"
        case LibraryElement.Album.rawValue:
            return "Albums"
        case LibraryElement.Song.rawValue:
            return "Songs"
        default:
            return ""
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section+1 {
        case LibraryElement.Artist.rawValue:
            return artistsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Album.rawValue:
            return albumsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        case LibraryElement.Song.rawValue:
            return songsFetchedResultsController.sections?[0].numberOfObjects ?? 0
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section+1 {
        case LibraryElement.Artist.rawValue:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let artist = artistsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(container: artist, rootView: self)
            return cell
        case LibraryElement.Album.rawValue:
            let cell: GenericTableCell = dequeueCell(for: tableView, at: indexPath)
            let album = albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(container: album, rootView: self)
            return cell
        case LibraryElement.Song.rawValue:
            let cell: SongTableCell = dequeueCell(for: tableView, at: indexPath)
            let song = songsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            cell.display(song: song, playContextCb: self.convertCellViewToPlayContext, rootView: self)
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section+1 {
        case LibraryElement.Artist.rawValue:
            return artistsFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Album.rawValue:
            return albumsFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        case LibraryElement.Song.rawValue:
            return songsFetchedResultsController.sections?[0].numberOfObjects ?? 0 > 0 ? CommonScreenOperations.tableSectionHeightLarge : 0
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section+1 {
        case LibraryElement.Artist.rawValue:
            return GenericTableCell.rowHeight
        case LibraryElement.Album.rawValue:
            return GenericTableCell.rowHeight
        case LibraryElement.Song.rawValue:
            return SongTableCell.rowHeight
        default:
            return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section+1 {
        case LibraryElement.Artist.rawValue:
            let artist = artistsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toArtistDetail.rawValue, sender: artist)
        case LibraryElement.Album.rawValue:
            let album = albumsFetchedResultsController.getWrappedEntity(at: IndexPath(row: indexPath.row, section: 0))
            performSegue(withIdentifier: Segues.toAlbumDetail.rawValue, sender: album)
        case LibraryElement.Song.rawValue: break
        default: break
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == Segues.toArtistDetail.rawValue {
            let vc = segue.destination as! ArtistDetailVC
            let artist = sender as? Artist
            vc.artist = artist
        }
        if segue.identifier == Segues.toAlbumDetail.rawValue {
            let vc = segue.destination as! AlbumDetailVC
            let album = sender as? Album
            vc.album = album
        }
    }
    
    override func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        if searchText.count > 0, searchController.searchBar.selectedScopeButtonIndex == 0 {
            artistsFetchedResultsController.search(searchText: searchText, onlyCached: false)
            albumsFetchedResultsController.search(searchText: searchText, onlyCached: false)
            songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: false)
        } else if searchController.searchBar.selectedScopeButtonIndex == 1 {
            artistsFetchedResultsController.search(searchText: searchText, onlyCached: true)
            albumsFetchedResultsController.search(searchText: searchText, onlyCached: true)
            songsFetchedResultsController.search(searchText: searchText, onlyCachedSongs: true)
        } else {
            artistsFetchedResultsController.showAllResults()
            albumsFetchedResultsController.showAllResults()
            songsFetchedResultsController.showAllResults()
        }
        tableView.reloadData()
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        var section: Int = 0
        switch controller {
        case artistsFetchedResultsController.fetchResultsController:
            section = LibraryElement.Artist.rawValue - 1
        case albumsFetchedResultsController.fetchResultsController:
            section = LibraryElement.Album.rawValue - 1
        case songsFetchedResultsController.fetchResultsController:
            section = LibraryElement.Song.rawValue - 1
        default:
            return
        }
        
        resultUpdateHandler?.applyChangesOfMultiRowType(controller, didChange: anObject, determinedSection: section, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    override func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    }
    
}
