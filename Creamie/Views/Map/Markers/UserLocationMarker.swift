//
//  UserLocationMarker.swift
//  Creamie
//
//  Created by Siqi Xu on 7/8/25.
//

import SwiftUI

struct UserLocationMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.pink)
                .frame(width: 30, height: 30)
                .shadow(radius: 4)
            
            Image(systemName: "person.fill")
                .foregroundColor(Color.white)
                .font(.system(size: 14, weight: .bold))
        }
    }
}
