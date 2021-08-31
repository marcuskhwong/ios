//
//  NCNotification.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 27/01/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
import NCCommunication
import SwiftyJSON

class NCNotification: UITableViewController, NCNotificationCellDelegate, NCEmptyDataSetDelegate {
  
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var notifications: [NCCommunicationNotifications] = []
    var emptyDataSet: NCEmptyDataSet?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("_notification_", comment: "")
        view.backgroundColor = NCBrandColor.shared.systemBackground

        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50.0
        tableView.allowsSelection = false
        tableView.backgroundColor = NCBrandColor.shared.systemBackground
        
        // Empty
        let offset = (self.navigationController?.navigationBar.bounds.height ?? 0) - 20
        emptyDataSet = NCEmptyDataSet.init(view: tableView, offset: -offset, delegate: self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        
        changeTheming()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        appDelegate.activeViewController = self
        
        //
        NotificationCenter.default.addObserver(self, selector: #selector(initialize), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        getNetwokingNotification()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterInitialize), object: nil)
    }
    
    @objc func viewClose() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - NotificationCenter

    @objc func initialize() {
        getNetwokingNotification()
    }
    
    @objc func changeTheming() {
        tableView.reloadData()
    }
    
    // MARK: - Empty
    
    func emptyDataSetView(_ view: NCEmptyView) {
        
        view.emptyImage.image = UIImage.init(named: "bell")?.image(color: .gray, size: UIScreen.main.bounds.width)
        view.emptyTitle.text = NSLocalizedString("_no_notification_", comment: "")
        view.emptyDescription.text = ""
    }
    
    // MARK: - Table

    @objc func reloadDatasource() {
        self.tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        emptyDataSet?.numberOfItemsInSection(notifications.count, section: section)
        return notifications.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! NCNotificationCell
        cell.delegate = self
        
        let notification = notifications[indexPath.row]
        let urlIcon = URL(string: notification.icon)
        var image: UIImage?
        
        if let urlIcon = urlIcon {
            let pathFileName = String(CCUtility.getDirectoryUserData()) + "/" + urlIcon.deletingPathExtension().lastPathComponent + ".png"
            image = UIImage(contentsOfFile: pathFileName)
        }
        
        if let image = image {
            cell.icon.image = image.imageColor(NCBrandColor.shared.brandElement)
        } else {
            cell.icon.image = NCUtility.shared.loadImage(named: "bell", color: NCBrandColor.shared.brandElement)
        }
        
        // Avatar
        cell.avatar.isHidden = true
        cell.avatarLeadingMargin.constant = 10
        if let subjectRichParameters = notification.subjectRichParameters {
            if let json = JSON(subjectRichParameters).dictionary {
                if let user = json["user"]?["id"].stringValue {
                    
                    let fileName = String(CCUtility.getUserUrlBase(appDelegate.user, urlBase: appDelegate.urlBase)) + "-" + user + ".png"
                    let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName
                    
                    if FileManager.default.fileExists(atPath: fileNameLocalPath) {
                        if let image = UIImage(contentsOfFile: fileNameLocalPath) {
                            cell.avatar.isHidden = false
                            cell.avatarLeadingMargin.constant = 50
                            cell.avatar.image = image
                        }
                    } else {
                        cell.avatar.isHidden = false
                        cell.avatarLeadingMargin.constant = 50
                        cell.fileUser = user
                        NCOperationQueue.shared.downloadAvatar(user: user, fileName: fileName, placeholder: UIImage(named: "avatar"), cell: cell, view: tableView)
                    }
                }
            }
        }
        
        cell.date.text = DateFormatter.localizedString(from: notification.date as Date, dateStyle: .medium, timeStyle: .medium)
        cell.notification = notification
        cell.date.text = CCUtility.dateDiff(notification.date as Date)
        cell.date.textColor = .gray
        cell.subject.text = notification.subject
        cell.subject.textColor = NCBrandColor.shared.label
        cell.message.text = notification.message.replacingOccurrences(of: "<br />", with: "\n")
        cell.message.textColor = .gray
        
        cell.remove.setImage(UIImage(named: "xmark")!.image(color: .gray, size: 20), for: .normal)
        
        cell.primary.isEnabled = false
        cell.primary.isHidden = true
        cell.primary.titleLabel?.font = .systemFont(ofSize: 14)
        cell.primary.setTitleColor(.white, for: .normal)
        cell.primary.layer.cornerRadius = 15
        cell.primary.layer.masksToBounds = true
        cell.primary.layer.backgroundColor = NCBrandColor.shared.brandElement.cgColor
        
        cell.secondary.isEnabled = false
        cell.secondary.isHidden = true
        cell.secondary.titleLabel?.font = .systemFont(ofSize: 14)
        cell.secondary.setTitleColor(.gray, for: .normal)
        cell.secondary.layer.cornerRadius = 15
        cell.secondary.layer.masksToBounds = true
        cell.secondary.layer.backgroundColor = NCBrandColor.shared.systemGray5.cgColor
        cell.secondary.layer.borderWidth = 0.3
        cell.secondary.layer.borderColor = UIColor.gray.cgColor
        
        cell.messageBottomMargin.constant = 10
        
        // Action
        if let actions = notification.actions {
            if let jsonActions = JSON(actions).array {
                if jsonActions.count == 1 {
                    let action = jsonActions[0]
                    
                    cell.primary.isEnabled = true
                    cell.primary.isHidden = false
                    cell.primary.setTitle(action["label"].stringValue, for: .normal)
                    
                } else if jsonActions.count == 2 {
                    
                    cell.primary.isEnabled = true
                    cell.primary.isHidden = false
                        
                    cell.secondary.isEnabled = true
                    cell.secondary.isHidden = false
                    
                    for action in jsonActions {
                            
                        let label =  action["label"].stringValue
                        let primary = action["primary"].boolValue
                            
                        if primary {
                            cell.primary.setTitle(label, for: .normal)
                        } else {
                            cell.secondary.setTitle(label, for: .normal)
                        }
                    }
                }
                
                let widthPrimary = cell.primary.intrinsicContentSize.width + 30;
                let widthSecondary = cell.secondary.intrinsicContentSize.width + 30;
                
                if widthPrimary > widthSecondary {
                    cell.primaryWidth.constant = widthPrimary
                    cell.secondaryWidth.constant = widthPrimary
                } else {
                    cell.primaryWidth.constant = widthSecondary
                    cell.secondaryWidth.constant = widthSecondary
                }
                
                cell.messageBottomMargin.constant = 40
            }
        }
        
        return cell
    }
    
    // MARK: - tap Action
    
    func tapRemove(with notification: NCCommunicationNotifications?) {
           
        NCCommunication.shared.setNotification(serverUrl:nil, idNotification: notification!.idNotification , method: "DELETE") { (account, errorCode, errorDescription) in
            if errorCode == 0 && account == self.appDelegate.account {
                                
                if let index = self.notifications.firstIndex(where: {$0.idNotification == notification!.idNotification})  {
                    self.notifications.remove(at: index)
                }
                
                self.reloadDatasource()
                
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            } else {
                print("[LOG] It has been changed user during networking process, error.")
            }
        }
    }

    func tapAction(with notification: NCCommunicationNotifications?, label: String) {
        
        if let actions = notification!.actions {
            if let jsonActions = JSON(actions).array {
                for action in jsonActions {
                    if action["label"].string == label {
                        let serverUrl = action["link"].stringValue
                        let method = action["type"].stringValue
                            
                        NCCommunication.shared.setNotification(serverUrl: serverUrl, idNotification: 0, method: method) { (account, errorCode, errorDescription) in
                            
                            if errorCode == 0 && account == self.appDelegate.account {
                                                        
                                if let index = self.notifications.firstIndex(where: {$0.idNotification == notification!.idNotification})  {
                                    self.notifications.remove(at: index)
                                }
                                
                                self.reloadDatasource()
                                
                            } else if errorCode != 0 {
                                NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                            } else {
                                print("[LOG] It has been changed user during networking process, error.")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Load notification networking
    
    func getNetwokingNotification() {
    
        NCUtility.shared.startActivityIndicator(backgroundView: self.navigationController?.view, blurEffect: true)

        NCCommunication.shared.getNotifications() { (account, notifications, errorCode, errorDescription) in
         
            if errorCode == 0 && account == self.appDelegate.account {
                    
                self.notifications.removeAll()
                let sortedListOfNotifications = (notifications! as NSArray).sortedArray(using: [NSSortDescriptor(key: "date", ascending: false)])
                    
                for notification in sortedListOfNotifications {
                    if let icon = (notification as! NCCommunicationNotifications).icon {
                        NCUtility.shared.convertSVGtoPNGWriteToUserData(svgUrlString: icon, fileName: nil, width: 25, rewrite: false, account: self.appDelegate.account, closure: { (imageNamePath) in })
                    }                    
                    self.notifications.append(notification as! NCCommunicationNotifications)
                }
                
                self.reloadDatasource()
            }
            
            NCUtility.shared.stopActivityIndicator()
        }
    }
}

// MARK: -

class NCNotificationCell: UITableViewCell, NCCellProtocol {
    
    @IBOutlet weak var icon : UIImageView!
    @IBOutlet weak var avatar : UIImageView!
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var subject: UILabel!
    @IBOutlet weak var message: UILabel!
    @IBOutlet weak var remove: UIButton!
    @IBOutlet weak var primary: UIButton!
    @IBOutlet weak var secondary: UIButton!
    @IBOutlet weak var avatarLeadingMargin: NSLayoutConstraint!
    @IBOutlet weak var messageBottomMargin: NSLayoutConstraint!
    @IBOutlet weak var primaryWidth: NSLayoutConstraint!
    @IBOutlet weak var secondaryWidth: NSLayoutConstraint!
    
    private var user = ""

    var delegate: NCNotificationCellDelegate?
    var notification: NCCommunicationNotifications?
    
    var filePreviewImageView : UIImageView? {
        get {
            return nil
        }
    }
    var fileAvatarImageView: UIImageView? {
        get {
            return avatar
        }
    }
    var fileObjectId: String? {
        get {
            return nil
        }
    }
    var fileUser: String? {
        get {
            return user
        }
        set {
            user = newValue ?? ""
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    @IBAction func touchUpInsideRemove(_ sender: Any) {
        delegate?.tapRemove(with: notification)
    }
    
    @IBAction func touchUpInsidePrimary(_ sender: Any) {
        let button = sender as! UIButton
        delegate?.tapAction(with: notification, label: button.titleLabel!.text!)
    }
    
    @IBAction func touchUpInsideSecondary(_ sender: Any) {
        let button = sender as! UIButton
        delegate?.tapAction(with: notification, label: button.titleLabel!.text!)
    }
}

protocol NCNotificationCellDelegate {
    func tapRemove(with notification: NCCommunicationNotifications?)
    func tapAction(with notification: NCCommunicationNotifications?, label: String)
}
