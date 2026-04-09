# Requirements Document

## Introduction

This specification addresses a critical bug in the dog profile photo editing functionality where deleting any photo always deletes the first photo (slot 0) instead of the intended photo. The issue occurs when users tap delete buttons on different photo slots, but the system incorrectly processes all deletions as slot 0 deletions, leading to unintended photo removal.

## Glossary

- **Photo_Slot**: A fixed position (0-5) in the photo grid where photos can be displayed
- **EditDogView**: The SwiftUI view responsible for editing dog profile information including photos
- **Existing_Photo**: A photo that was previously saved and is loaded from the server
- **New_Photo**: A photo selected by the user but not yet saved to the server
- **Photo_Deletion_Handler**: The method responsible for removing photos from specific slots

## Requirements

### Requirement 1

**User Story:** As a dog owner editing my dog's profile, I want to delete a specific photo by tapping its delete button, so that only the intended photo is removed from the profile.

#### Acceptance Criteria

1. WHEN a user taps the delete button on photo slot N, THE Photo_Deletion_Handler SHALL remove only the photo from slot N
2. WHEN a user taps the delete button on photo slot N, THE Photo_Deletion_Handler SHALL preserve all photos in other slots (0 to 5, excluding N)
3. WHEN a photo is deleted from slot N, THE EditDogView SHALL update the UI to show slot N as empty
4. WHEN multiple photos are deleted in sequence, THE Photo_Deletion_Handler SHALL track each deletion independently by slot index
5. THE Photo_Deletion_Handler SHALL log the correct slot index for each deletion operation

### Requirement 2

**User Story:** As a dog owner, I want the photo deletion to work correctly for both existing and new photos, so that I can manage my dog's photo gallery accurately.

#### Acceptance Criteria

1. WHEN deleting an existing photo from slot N, THE Photo_Deletion_Handler SHALL add only that photo URL to the deletion queue
2. WHEN deleting a new photo from slot N, THE Photo_Deletion_Handler SHALL clear only the selected image data for slot N
3. THE Photo_Deletion_Handler SHALL maintain separate tracking for existing photos and new photos
4. WHEN a photo is deleted, THE EditDogView SHALL immediately reflect the change in the photo grid
5. THE Photo_Deletion_Handler SHALL prevent deletion if it would result in fewer than the minimum required photos

### Requirement 3

**User Story:** As a developer debugging photo deletion issues, I want accurate logging of deletion operations, so that I can verify the correct slot indices are being processed.

#### Acceptance Criteria

1. WHEN a delete button is tapped, THE Photo_Deletion_Handler SHALL log the exact slot index being processed
2. WHEN a photo is deleted, THE Photo_Deletion_Handler SHALL log the photo URL or identifier being removed
3. THE Photo_Deletion_Handler SHALL log the remaining photos after each deletion operation
4. WHEN multiple deletions occur, THE Photo_Deletion_Handler SHALL log each operation with distinct slot indices
5. THE logging system SHALL clearly distinguish between existing photo deletions and new photo deletions