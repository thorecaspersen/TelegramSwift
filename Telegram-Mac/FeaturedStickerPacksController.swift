//
//  FeaturedStickerPacksController.swift
//  Telegram
//
//  Created by keepcoder on 28/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac

private final class FeaturedStickerPacksControllerArguments {
    let context: AccountContext
    
    let openStickerPack: (StickerPackCollectionInfo) -> Void
    let addPack: (StickerPackCollectionInfo) -> Void
    
    init(context: AccountContext, openStickerPack: @escaping (StickerPackCollectionInfo) -> Void, addPack: @escaping (StickerPackCollectionInfo) -> Void) {
        self.context = context
        self.openStickerPack = openStickerPack
        self.addPack = addPack
    }
}

private enum FeaturedStickerPacksSection: Int32 {
    case stickers
}

private enum FeaturedStickerPacksEntryId: Hashable {
    case pack(ItemCollectionId)
    case section(Int32)
    var hashValue: Int {
        switch self {
        case let .pack(id):
            return id.hashValue
        case let .section(id):
            return id.hashValue
        }
    }
}

private enum FeaturedStickerPacksEntry: TableItemListNodeEntry {
    case section(sectionId:Int32)
    case pack(sectionId:Int32, Int32, StickerPackCollectionInfo, Bool, StickerPackItem?, Int32, Bool)
    
    
    var stableId: FeaturedStickerPacksEntryId {
        switch self {
        case let .pack(_, _, info, _, _, _, _):
            return .pack(info.id)
        case let .section(id):
            return .section(id)
        }
    }
    
    var stableIndex:Int32 {
        switch self {
        case let .pack(sectionId: sectionId, index, _, _, _, _, _):
            fatalError()
        case let .section(sectionId: sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    var index:Int32 {
        switch self {
        case let .pack(sectionId: sectionId, index, _, _, _, _, _):
            return (sectionId * 1000) + 100 + index
        case let .section(sectionId: sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    static func <(lhs: FeaturedStickerPacksEntry, rhs: FeaturedStickerPacksEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(_ arguments: FeaturedStickerPacksControllerArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .pack(_, _, info, unread, topItem, count, installed):
            return StickerSetTableRowItem(initialSize, context: arguments.context, stableId: stableId, info: info, topItem: topItem, itemCount: count, unread: false, editing: ItemListStickerPackItemEditing(editable: false, editing: false), enabled: true, control: .installation(installed: installed), action: {
                arguments.openStickerPack(info)
            }, addPack: {
                arguments.addPack(info)
            }, removePack: {
                
            })

           /*
             return ItemListStickerPackItem(account: arguments.account, packInfo: info, itemCount: count, topItem: topItem, unread: unread, control: .installation(installed: installed), editing: ItemListStickerPackItemEditing(editable: false, editing: false, revealed: false), enabled: true, sectionId: self.section, action: { _ in
             arguments.openStickerPack(info)
             }, addPack: {
             arguments.addPack(info)
             }, removePack: { _ in
             })
 */
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

private struct FeaturedStickerPacksControllerState: Equatable {
    init() {
    }
    
    static func ==(lhs: FeaturedStickerPacksControllerState, rhs: FeaturedStickerPacksControllerState) -> Bool {
        return true
    }
}

private func featuredStickerPacksControllerEntries(state: FeaturedStickerPacksControllerState, view: CombinedView, featured: [FeaturedStickerPackItem], unreadPacks: [ItemCollectionId: Bool]) -> [FeaturedStickerPacksEntry] {
    var entries: [FeaturedStickerPacksEntry] = []
    
    var sectionId:Int32 = 1
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    if let stickerPacksView = view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView, !featured.isEmpty {
        if let packsEntries = stickerPacksView.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks] {
            var installedPacks = Set<ItemCollectionId>()
            for entry in packsEntries {
                installedPacks.insert(entry.id)
            }
            var index: Int32 = 0
            for item in featured {
                var unread = false
                if let value = unreadPacks[item.info.id] {
                    unread = value
                }
                entries.append(.pack(sectionId: sectionId, index, item.info, unread, item.topItems.first, item.info.count, installedPacks.contains(item.info.id)))
                index += 1
            }
        }
    }
    
    return entries
}

private func prepareTransition(left:[AppearanceWrapperEntry<FeaturedStickerPacksEntry>], right: [AppearanceWrapperEntry<FeaturedStickerPacksEntry>], initialSize: NSSize, arguments: FeaturedStickerPacksControllerArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}


class FeaturedStickerPacksController: TableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let statePromise = ValuePromise(FeaturedStickerPacksControllerState(), ignoreRepeated: true)
        //let stateValue = Atomic(value: FeaturedStickerPacksControllerState())
        /*let updateState: ((FeaturedStickerPacksControllerState) -> FeaturedStickerPacksControllerState) -> Void = { f in
         statePromise.set(stateValue.modify { f($0) })
         }*/
        
        let context = self.context
        
        let actionsDisposable = DisposableSet()
        
        let resolveDisposable = MetaDisposable()
        actionsDisposable.add(resolveDisposable)
        
        let arguments = FeaturedStickerPacksControllerArguments(context: context, openStickerPack: { info in
           showModal(with: StickersPackPreviewModalController(context, peerId: nil, reference: .name(info.shortName)), for: mainWindow)
        }, addPack: { info in
            showModal(with: StickersPackPreviewModalController(context, peerId: nil, reference: .name(info.shortName)), for: mainWindow)
        })
        
        let stickerPacks = Promise<CombinedView>()
        stickerPacks.set(context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])]))
        
        let featured = Promise<[FeaturedStickerPackItem]>()
        featured.set(context.account.viewTracker.featuredStickerPacks())
        
        var initialUnreadPacks: [ItemCollectionId: Bool] = [:]
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<FeaturedStickerPacksEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        
        genericView.merge(with: combineLatest(statePromise.get(), stickerPacks.get(), featured.get(), appearanceSignal) |> deliverOnMainQueue
            |> map { state, view, featured, appearance -> TableUpdateTransition in
                
                for item in featured {
                    if initialUnreadPacks[item.info.id] == nil {
                        initialUnreadPacks[item.info.id] = item.unread
                    }
                }
                let entries = featuredStickerPacksControllerEntries(state: state, view: view, featured: featured, unreadPacks: initialUnreadPacks).map{AppearanceWrapperEntry(entry: $0, appearance: appearance)}
                
                return prepareTransition(left: previousEntries.swap(entries), right: entries, initialSize: initialSize.modify({$0}), arguments: arguments)
            } |> afterDisposed {
                actionsDisposable.dispose()
        } )
        
        
        var alreadyReadIds = Set<ItemCollectionId>()
        
        genericView.addScroll(listener: TableScrollListener ({ scroll in
           
        }))
        
        readyOnce()
    }
}
