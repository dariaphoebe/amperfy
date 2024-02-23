//
//  BasicCollectionCell.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 28.09.22.
//  Copyright (c) 2022 Maximilian Bauer. All rights reserved.
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

class BasicCollectionCell: UICollectionViewCell {

    static let margin = UIView.defaultMarginCell
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layoutMargins = BasicTableCell.margin
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override var layoutMargins: UIEdgeInsets { get { return BasicTableCell.margin } set { } }

}
