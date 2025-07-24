//
//  SupabaseClient.swift
//  Creamie
//
//  Created by Siqi Xu on 2025/7/24.
//

import Foundation
import Supabase

struct SupabaseConfig {
    static let url: URL = {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not found in Info.plist")
        }
        return url
    }()
    
    static let anonKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist")
        }
        return key
    }()
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey
)
