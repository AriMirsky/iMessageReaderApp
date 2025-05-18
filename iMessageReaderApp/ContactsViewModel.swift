//
//  ContactsViewModel.swift
//  iMessageReaderApp
//
//  Created by Ari Mirsky on 5/16/25.
//


import Foundation
import Contacts
import Combine

/// An ObservableObject that loads the user’s contacts
/// and builds a [handleID: displayName] lookup.
final class ContactsViewModel: ObservableObject {
    @Published private(set) var nameByHandle: [String:String] = [:]
    private let store = CNContactStore()

    init() {
        requestAccessAndLoad()
    }
    
    func displayName(for handle: String) -> String {
      // 1. normalize the raw handle
      let rawKey: String = {
        if handle.contains("@") {
          return handle.lowercased()
        } else {
          return handle.filter(\.isNumber)
        }
      }()

      // 2. direct lookup
      if let name = nameByHandle[rawKey] {
        return name
      }

      // 3. try stripping a leading “1” (common US country code)
      if rawKey.count > 10,
         rawKey.hasPrefix("1"),
         let name = nameByHandle[String(rawKey.dropFirst())] {
        return name
      }

      // 4. try adding a leading “1” if it’s only 10 digits
      if rawKey.count == 10,
         let name = nameByHandle["1" + rawKey] {
        return name
      }

      // 5. as a last resort, try a suffix match (last 7 digits)
      let suffix = String(rawKey.suffix(7))
      if let (key, name) = nameByHandle.first(where: { $0.key.hasSuffix(suffix) }) {
        return name
      }

      // Nothing matched, fall back to the raw value
      print("⚠️ Unmatched handle:", handle, "→ key:", rawKey)
      return handle
    }



    private func requestAccessAndLoad() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            loadContacts()
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                if granted { self.loadContacts() }
            }
        default:
            // denied/restricted: you might display an alert or do nothing
            break
        }
    }

    private func loadContacts() {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        let req = CNContactFetchRequest(keysToFetch: keys)
        req.unifyResults = true

        var mapping: [String:String] = [:]
        do {
            try store.enumerateContacts(with: req) { contact, _ in
                let fullName = "\(contact.givenName) \(contact.familyName)"
                    .trimmingCharacters(in: .whitespaces)

                // phones → normalized digits
                contact.phoneNumbers.forEach { labelled in
                    let raw = labelled.value.stringValue
                    let digits = raw.filter(\.isNumber)
                    if !digits.isEmpty { mapping[digits] = fullName }
                }

                // emails → lowercase
                contact.emailAddresses.forEach { labelled in
                    let email = (labelled.value as String).lowercased()
                    if !email.isEmpty { mapping[email] = fullName }
                }
            }
            DispatchQueue.main.async {
                self.nameByHandle = mapping
            }
        } catch {
            print("⚠️ Contacts fetch failed:", error)
        }
        // in ContactsViewModel.loadContacts(), after you assemble `mapping`:
        print("Loaded \(mapping.count) contacts into the nameByHandle lookup")
    }
}
