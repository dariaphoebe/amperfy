//
//  LibraryElementDetailTableHeaderView.swift
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
import AmperfyKit

typealias GetInfoCallback = () -> String


struct PlayShuffleInfoConfiguration {
    var infoCB: GetInfoCallback?
    var playContextCb: GetPlayContextCallback?
    var player: PlayerFacade
    let isInfoAlwaysHidden: Bool
    var customPlayName: String? = nil
    var isShuffleHidden = false
    var isShuffleOnContextNeccessary: Bool = true
    var shuffleContextCb: GetPlayContextCallback? = nil
    var isEmbeddedInOtherView: Bool = false
}

class LibraryElementDetailTableHeaderView: UIView {
    
    @IBOutlet weak var playAllButton: UIButton!
    @IBOutlet weak var playShuffledButton: UIButton!
    @IBOutlet weak var infoContainerView: UIView!
    @IBOutlet weak var infoLabel: UILabel!
    
    static let frameHeight: CGFloat = 40.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginMiddleElement
    
    private var config: PlayShuffleInfoConfiguration?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layoutMargins = UIEdgeInsets(top: 0.0, left: UIView.defaultMarginX, bottom: 0.0, right: UIView.defaultMarginX)
    }
    
    public static func createTableHeader(rootView: BasicTableViewController, configuration: PlayShuffleInfoConfiguration) -> LibraryElementDetailTableHeaderView? {
        rootView.tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: rootView.view.bounds.size.width, height: Self.frameHeight))
        let genericDetailTableHeaderView = ViewBuilder<LibraryElementDetailTableHeaderView>.createFromNib(withinFixedFrame: CGRect(x: 0, y: 0, width: rootView.view.bounds.size.width, height: Self.frameHeight))!
        genericDetailTableHeaderView.prepare(configuration: configuration)
        rootView.tableView.tableHeaderView?.addSubview(genericDetailTableHeaderView)
        return genericDetailTableHeaderView
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }
    
    func refresh() {
        guard let config = config else { return }
        if config.isEmbeddedInOtherView {
            self.layoutMargins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        } else {
            if traitCollection.horizontalSizeClass == .compact {
                self.layoutMargins = UIEdgeInsets(top: 0.0, left: UIView.defaultMarginCellX, bottom: 0.0, right: UIView.defaultMarginCellX)
            } else {
                self.layoutMargins = UIEdgeInsets(top: 0.0, left: UIView.defaultMarginX, bottom: 0.0, right: UIView.defaultMarginX)
            }
        }
        infoContainerView.isHidden = config.isInfoAlwaysHidden || (traitCollection.horizontalSizeClass == .compact)
        infoLabel.text = config.infoCB?() ?? ""
    }
    
    @IBAction func playAllButtonPressed(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        play(isShuffled: false)
    }
    
    @IBAction func addAllShuffledButtonPressed(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        shuffle()
    }
    
    private func play(isShuffled: Bool) {
        guard let playContext = config?.playContextCb?(), let player = config?.player else { return }
        isShuffled ? player.playShuffled(context: playContext) : player.play(context: playContext)
    }
    
    private func shuffle() {
        guard let player = config?.player else { return }
        if let shuffleContext = config?.shuffleContextCb?() {
            if config?.isShuffleOnContextNeccessary ?? true {
                player.playShuffled(context: shuffleContext)
            } else {
                player.play(context: shuffleContext)
            }
        } else {
            play(isShuffled: true)
        }
    }
    
    /// isShuffleOnContextNeccessary: In AlbumsVC the albums are shuffled, keep the order when shuffle button is pressed
    func prepare(configuration: PlayShuffleInfoConfiguration) {
        self.config = configuration
        playAllButton.setTitle(config?.customPlayName ?? "Play", for: .normal)
        playShuffledButton.setTitle(configuration.isShuffleOnContextNeccessary ? "Shuffle" : "Random", for: .normal)
        playShuffledButton.isHidden = configuration.isShuffleHidden
        activate()
    }
    
    func activate() {
        playAllButton.isEnabled = true
        playShuffledButton.isEnabled = true
    }
    
    func deactivate() {
        playAllButton.isEnabled = false
        playShuffledButton.isEnabled = false
    }
    
}
