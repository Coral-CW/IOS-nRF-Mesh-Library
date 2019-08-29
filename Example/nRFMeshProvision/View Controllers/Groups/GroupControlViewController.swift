//
//  GroupControlViewController.swift
//  nRFMeshProvision_Example
//
//  Created by Aleksander Nowakowski on 27/08/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import UIKit
import nRFMeshProvision

private class Section {
    let applicationKey: ApplicationKey
    var models: [(modelId: UInt32, count: Int)] = []
    
    init(_ applicationKey: ApplicationKey) {
        self.applicationKey = applicationKey
    }
}

private extension Array where Element == Section {
    
    subscript(applicationKey: ApplicationKey) -> Section? {
        if let index = firstIndex(where: { $0.applicationKey == applicationKey }) {
            return self[index]
        }
        return nil
    }
    
}

class GroupControlViewController: ConnectableCollectionViewController {
    
    // MARK: - Properties
    
    var group: Group!
    
    private var sections: [Section] = []
    
    // MARK: - Implementation
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = group.name
        collectionView.delegate = self
        
        if let network = MeshNetworkManager.instance.meshNetwork {
            let models = network.models(subscribedTo: group)
            models.forEach { model in
                model.boundApplicationKeys.forEach { key in
                    if model.isSupported {
                        var section: Section! = sections[key]
                        if section == nil {
                            section = Section(key)
                            sections.append(section)
                        }
                        if let index = section.models.firstIndex(where: { $0.modelId == model.modelId }) {
                            section.models[index].count += 1
                        } else {
                            section.models.append((modelId: model.modelId, count: 1))
                        }
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        MeshNetworkManager.instance.delegate = self
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "edit" {
            let destination = segue.destination as! UINavigationController
            let viewController = destination.topViewController as! AddGroupViewController
            viewController.group = group
            viewController.delegate = self
        }
    }

    // MARK: - UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let section = sections[section]
        return section.models.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "key", for: indexPath) as! SectionView
        header.title.text = sections[indexPath.section].applicationKey.name.uppercased()
        return header
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let section = sections[indexPath.section]
        let model = section.models[indexPath.row]
        let identifier = String(format: "%08X", model.modelId)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! ModelGroupCell
        cell.group = group
        cell.applicationKey = section.applicationKey
        cell.delegate = self
        cell.numberOfDevices = model.count
        return cell
    }
}

extension GroupControlViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset: CGFloat = 16
        let standardSize: CGFloat = 130
        let numberOfColumnsOnCompactWidth: CGFloat = 3
        let width = view.frame.width - inset * 2
        if width > standardSize * numberOfColumnsOnCompactWidth + inset * (numberOfColumnsOnCompactWidth - 1) {
            return CGSize(width: standardSize, height: standardSize)
        }
        return CGSize(width: width / 2 - inset / 2, height: standardSize)
    }
    
}

extension GroupControlViewController: AddGroupDelegate {
    
    func groupChanged(_ group: Group) {
        title = group.name
    }
    
}

extension GroupControlViewController: ModelGroupViewCellDelegate {
    
    func send(_ message: MeshMessage, description: String, using applicationKey: ApplicationKey) {
        whenConnected { alert in
            alert?.message = description
            MeshNetworkManager.instance.send(message, to: self.group, using: applicationKey)
        }
    }
    
}

extension GroupControlViewController: MeshNetworkDelegate {
    
    func meshNetwork(_ meshNetwork: MeshNetwork, didDeliverMessage message: MeshMessage, from source: Address) {
        // Has the Node been reset remotely.
        guard !(message is ConfigNodeReset) else {
            (UIApplication.shared.delegate as! AppDelegate).meshNetworkDidChange()
            navigationController?.popToRootViewController(animated: true)
            return
        }
    }
    
    func meshNetwork(_ meshNetwork: MeshNetwork, didDeliverMessage message: MeshMessage, to destination: Address) {
        done()
    }
    
    func meshNetwork(_ meshNetwork: MeshNetwork, failedToDeliverMessage message: MeshMessage, to destination: Address, error: Error) {
        done() {
            self.presentAlert(title: "Error", message: "Message could not be sent.")
        }
    }
}

private extension Model {
    
    var isSupported: Bool {
        return modelIdentifier == 0x1000 ||
               modelIdentifier == 0x1002
    }
    
    var modelId: UInt32 {
        let companyId = isBluetoothSIGAssigned ? 0 : companyIdentifier!
        return (UInt32(companyId) << 16) | UInt32(modelIdentifier)
    }
    
}
