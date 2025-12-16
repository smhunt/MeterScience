"""
Activity Log Usage Examples

This file demonstrates how to integrate activity logging into existing routes.
Copy these patterns into your actual route files to log user activities.
"""

# Example 1: Log activity when a user creates a reading
# Add this to api/src/routes/readings.py in the create_reading function

from .activity import log_activity

# After successfully creating a reading and updating user XP:
await log_activity(
    db=db,
    user_id=current_user.id,
    activity_type="reading",
    description=f"Recorded meter reading: {reading.normalized_value}",
    metadata={
        "meter_id": str(reading.meter_id),
        "confidence": reading.confidence,
        "xp_earned": 10
    }
)


# Example 2: Log XP gain when leveling up
# Add this to wherever XP is awarded

# Check if user leveled up
old_level = current_user.level
new_xp = current_user.xp + xp_amount
new_level = calculate_level(new_xp)  # Your level calculation function

if new_level > old_level:
    await log_activity(
        db=db,
        user_id=current_user.id,
        activity_type="level_up",
        description=f"Leveled up to level {new_level}!",
        metadata={
            "old_level": old_level,
            "new_level": new_level,
            "total_xp": new_xp
        }
    )
else:
    await log_activity(
        db=db,
        user_id=current_user.id,
        activity_type="xp_gain",
        description=f"Earned {xp_amount} XP",
        metadata={
            "xp_amount": xp_amount,
            "total_xp": new_xp
        }
    )


# Example 3: Log badge earned
# Add this to wherever badges are awarded

await log_activity(
    db=db,
    user_id=current_user.id,
    activity_type="badge_earned",
    description=f"Earned badge: {badge_name}",
    metadata={
        "badge_id": badge_id,
        "badge_name": badge_name,
        "badge_tier": "gold"
    }
)


# Example 4: Log verification activity
# Add this to api/src/routes/verify.py when a user verifies a reading

await log_activity(
    db=db,
    user_id=current_user.id,
    activity_type="verification",
    description=f"Verified meter reading",
    metadata={
        "reading_id": str(reading_id),
        "vote": vote,  # "correct", "incorrect", "unclear"
        "xp_earned": 5
    }
)


# Example 5: Log streak maintenance
# Add this to wherever streak logic is handled

if streak_maintained:
    await log_activity(
        db=db,
        user_id=current_user.id,
        activity_type="streak",
        description=f"Maintained {current_user.streak_days} day streak!",
        metadata={
            "streak_days": current_user.streak_days,
            "bonus_xp": streak_bonus_xp
        }
    )
elif streak_broken:
    await log_activity(
        db=db,
        user_id=current_user.id,
        activity_type="streak",
        description="Streak reset",
        metadata={
            "previous_streak": previous_streak_days,
            "new_streak": 1
        }
    )


# Example 6: Log campaign participation
# Add this to api/src/routes/campaigns.py

await log_activity(
    db=db,
    user_id=current_user.id,
    activity_type="campaign",
    description=f"Joined campaign: {campaign.name}",
    metadata={
        "campaign_id": str(campaign.id),
        "campaign_name": campaign.name
    }
)
