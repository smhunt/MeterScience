# Feature: OCR Learning System

**Branch:** `feature/ocr-learning`
**Status:** Planned

## Overview

Implement a system that learns from each meter's photos to improve OCR accuracy over time. The system will:

1. **Auto-rotate images** to correct orientation
2. **Learn meter-specific parameters** (ROI, expected digit positions)
3. **Use reference images** to guide future recognition
4. **Batch improve** accuracy across all meters

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Photo Capture  │────▶│ Pre-processing  │────▶│   OCR Engine    │
│                 │     │ (rotation, crop)│     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                               ┌────────────────────────┘
                               ▼
                        ┌─────────────────┐
                        │  Learned Model  │
                        │   (per meter)   │
                        └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │   Refinement    │
                        │  (batch train)  │
                        └─────────────────┘
```

## Implementation Plan

### Phase 1: Image Pre-processing

**Files to create/modify:**
- `ios/MeterScience/Services/ImageProcessor.swift` (new)

**Tasks:**
1. [ ] Detect image orientation using Vision framework
2. [ ] Auto-rotate images to upright position
3. [ ] Detect text orientation (horizontal vs vertical meter displays)
4. [ ] Crop to region of interest (ROI)

```swift
class ImageProcessor {
    // Detect and correct rotation
    func normalizeOrientation(_ image: UIImage) -> UIImage

    // Detect text angle and rotate to horizontal
    func detectAndCorrectTextAngle(_ image: CIImage) -> CIImage

    // Find ROI containing digit display
    func detectMeterDisplayROI(_ image: CIImage) -> CGRect?
}
```

### Phase 2: Meter Learning Model

**Files to create/modify:**
- `ios/MeterScience/Models/MeterLearning.swift` (new)
- `api/src/routes/learning.py` (new)
- `api/src/models.py` (add MeterLearningParams)

**Data Model:**
```swift
struct MeterLearningParams: Codable {
    let meterId: UUID

    // Display characteristics
    let displayBounds: CGRect?      // Normalized ROI for digit display
    let displayAngle: Float?        // Rotation angle of display
    let digitSpacing: Float?        // Spacing between digits

    // Reference images
    let referenceImageUrl: String?  // Best quality reference photo
    let referenceReading: String?   // Confirmed reading for reference

    // OCR parameters
    let preferredContrast: Float?   // Best contrast setting
    let digitStyle: String?         // "lcd", "analog", "digital"

    // Confidence calibration
    let confidenceOffset: Float     // Adjust base confidence
    let historicalAccuracy: Float   // % of readings correct

    let lastUpdated: Date
}
```

**API Endpoints:**
```
POST /api/v1/meters/{id}/learning     # Upload learning params
GET  /api/v1/meters/{id}/learning     # Get current params
POST /api/v1/meters/{id}/reference    # Upload reference image
POST /api/v1/learning/batch-train     # Trigger batch improvement
```

### Phase 3: Reference Image System

**Tasks:**
1. [ ] Allow user to mark a successful reading as "reference"
2. [ ] Store reference image with confirmed reading
3. [ ] Use reference to guide future OCR:
   - Match ROI position
   - Compare digit patterns
   - Validate consistency

**UI Changes (SmartScanView.swift):**
- Add "Use as Reference" button after successful save
- Show reference image overlay option
- Display "Learning from this meter" indicator

### Phase 4: Batch Training Pipeline

**Backend Tasks:**
1. [ ] Collect all successful readings with images
2. [ ] Analyze common patterns per meter
3. [ ] Update learning parameters
4. [ ] Send updated params to app

**Batch Training Algorithm:**
```python
def batch_train_meter(meter_id: UUID):
    readings = get_verified_readings(meter_id)

    # Analyze successful readings
    rois = [detect_roi(r.image) for r in readings]
    angles = [detect_angle(r.image) for r in readings]

    # Compute optimal parameters
    params = MeterLearningParams(
        display_bounds=average_roi(rois),
        display_angle=median(angles),
        confidence_offset=calculate_offset(readings),
        historical_accuracy=calculate_accuracy(readings)
    )

    save_learning_params(meter_id, params)
```

### Phase 5: Feedback Loop

**Tasks:**
1. [ ] Track OCR accuracy (original vs edited readings)
2. [ ] Identify meters needing more training
3. [ ] Suggest re-calibration for poor performers
4. [ ] A/B test OCR parameter changes

## Implementation Order

1. **Sprint 1:** Image pre-processing (rotation, basic ROI)
2. **Sprint 2:** Learning model + API endpoints
3. **Sprint 3:** Reference image system
4. **Sprint 4:** Batch training pipeline
5. **Sprint 5:** Feedback loop + analytics

## Success Metrics

- Reduce OCR misreads by 50%
- Reduce manual entry rate from >20% to <5%
- Achieve 90%+ first-try accuracy after 10 readings per meter

## Testing Strategy

1. **Unit Tests:** Image rotation, ROI detection
2. **Integration Tests:** Learning params sync
3. **A/B Test:** Compare old vs new OCR pipeline
4. **Field Test:** Track accuracy on real meters over 2 weeks

## Dependencies

- Vision framework (iOS)
- Core ML (optional, for advanced learning)
- S3/MinIO for image storage
- Background job queue (batch training)
