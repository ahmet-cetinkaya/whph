import 'package:whph/core/domain/features/tasks/task.dart';
import 'package:whph/core/domain/features/habits/habit.dart';
import 'package:whph/core/domain/features/tags/tag.dart';
import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/domain/features/habits/habit_record.dart';
import 'package:whph/core/domain/features/tasks/task_time_record.dart';
import 'package:whph/core/domain/features/app_usages/app_usage.dart';
import 'package:whph/core/domain/features/app_usages/app_usage_time_record.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';

/// Contains all demo data that will be populated into the database
class DemoData {
  /// Demo tags to be created
  static List<Tag> get tags => [
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Work',
          color: 'FF6B6B',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Personal',
          color: '4ECDC4',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 29)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Health',
          color: '45B7D1',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 28)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Learning',
          color: '96CEB4',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 27)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Finance',
          color: 'FFEAA7',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 26)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Entertainment',
          color: 'FD79A8',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 25)),
        ),
        Tag(
          id: KeyHelper.generateStringId(),
          name: 'Social',
          color: '00B894',
          isArchived: false,
          createdDate: DateTime.now().subtract(const Duration(days: 24)),
        ),
      ];

  /// Demo habits to be created
  static List<Habit> get habits => [
        Habit(
          id: KeyHelper.generateStringId(),
          name: 'Meditation',
          description: 'Start the day with 10 minutes of mindfulness meditation',
          hasReminder: true,
          reminderTime: '07:00',
          reminderDays: '1,2,3,4,5,6,7', // Daily
          hasGoal: true,
          targetFrequency: 5,
          periodDays: 7,
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: 'Read',
          description: 'Read books, articles, or other educational material',
          hasReminder: true,
          reminderTime: '20:00',
          reminderDays: '1,2,3,4,5,6,7', // Daily
          hasGoal: true,
          targetFrequency: 6,
          periodDays: 7,
          createdDate: DateTime.now().subtract(const Duration(days: 14)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: 'Exercise',
          description: 'Physical workout or sports activity',
          hasReminder: true,
          reminderTime: '18:00',
          reminderDays: '1,3,5', // Monday, Wednesday, Friday
          hasGoal: true,
          targetFrequency: 3,
          periodDays: 7,
          createdDate: DateTime.now().subtract(const Duration(days: 10)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: 'Drink Water',
          description: 'Stay hydrated throughout the day',
          hasReminder: true,
          reminderTime: '09:00',
          reminderDays: '1,2,3,4,5,6,7', // Daily
          hasGoal: false, // No goal needed for this basic daily habit
          targetFrequency: 0,
          periodDays: 0,
          createdDate: DateTime.now().subtract(const Duration(days: 5)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: 'Vitamins',
          description: 'Daily vitamin supplements for health',
          hasReminder: true,
          reminderTime: '08:00',
          reminderDays: '1,2,3,4,5,6,7', // Daily
          hasGoal: false, // No goal needed for this basic daily habit
          targetFrequency: 0,
          periodDays: 0,
          createdDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
        Habit(
          id: KeyHelper.generateStringId(),
          name: 'Journal',
          description: 'Daily reflection and gratitude journaling',
          hasReminder: true,
          reminderTime: '21:00',
          reminderDays: '1,2,3,4,5,6,7', // Daily
          hasGoal: true,
          targetFrequency: 5,
          periodDays: 7,
          createdDate: DateTime.now().subtract(const Duration(days: 8)),
        ),
      ];

  /// Demo tasks to be created
  static List<Task> get tasks {
    // Store the buy groceries task ID for subtasks
    final buyGroceriesTaskId = KeyHelper.generateStringId();

    return [
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Complete Project Proposal',
        description: 'Prepare and submit the quarterly project proposal for review',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 2)),
        deadlineDate: DateTime.now().add(const Duration(days: 5)),
        createdDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Review Team Performance',
        description: 'Conduct quarterly performance reviews for team members',
        isCompleted: false,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 7)),
        deadlineDate: DateTime.now().add(const Duration(days: 14)),
        createdDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Update Resume',
        description: 'Add recent projects and achievements to resume',
        isCompleted: false,
        priority: EisenhowerPriority.notUrgentNotImportant,
        plannedDate: DateTime.now().add(const Duration(days: 10)),
        createdDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Task(
        id: buyGroceriesTaskId,
        title: 'Buy Groceries',
        description: 'Weekly grocery shopping for the household',
        isCompleted: false,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(), // Changed to today
        createdDate: DateTime.now(),
      ),
      // Subtasks for Buy Groceries
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Fresh Vegetables',
        description: 'Tomatoes, lettuce, carrots, onions, peppers',
        isCompleted: false,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(), // Changed to today
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Dairy Products',
        description: 'Milk, cheese, yogurt, butter',
        isCompleted: true,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(), // Changed to today
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Meat & Protein',
        description: 'Chicken breast, ground beef, eggs, salmon',
        isCompleted: false,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(), // Changed to today
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Pantry Staples',
        description: 'Rice, pasta, bread, olive oil, spices',
        isCompleted: false,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(), // Changed to today
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Buy Household Items',
        description: 'Toilet paper, cleaning supplies, laundry detergent',
        isCompleted: true,
        priority: EisenhowerPriority.urgentNotImportant,
        plannedDate: DateTime.now(), // Changed to today
        parentTaskId: buyGroceriesTaskId,
        createdDate: DateTime.now(),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Learn Microservices Architecture Patterns',
        description:
            'Study distributed system design patterns including circuit breaker, saga, and event sourcing for scalable applications',
        isCompleted: false,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 7)), // Moved to next week
        createdDate: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Call Mom',
        description: 'Weekly check-in call with family',
        isCompleted: false,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Review Code Changes',
        description: 'Review and approve pending pull requests',
        isCompleted: false,
        priority: EisenhowerPriority.urgentImportant,
        deadlineDate: DateTime.now().add(const Duration(hours: 5)),
        createdDate: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Backup Computer Files',
        description: 'Weekly backup of important documents and projects',
        isCompleted: false,
        priority: EisenhowerPriority.notUrgentNotImportant,
        plannedDate: DateTime.now().add(const Duration(days: 1)),
        createdDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Learn Flutter State Management',
        description: 'Complete online course on advanced Flutter state management patterns',
        isCompleted: false,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().add(const Duration(days: 3)),
        deadlineDate: DateTime.now().add(const Duration(days: 21)),
        createdDate: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Study Design Patterns',
        description: 'Review and practice implementing key design patterns: Observer, Factory, and Strategy patterns',
        isCompleted: true, // Completed learning task for today
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now(), // Today
        createdDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Learn API Documentation',
        description: 'Study REST API best practices and OpenAPI specification',
        isCompleted: true, // Another completed learning task for today
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now(), // Today
        createdDate: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Schedule Annual Health Checkup',
        description: 'Book appointment with primary care physician for annual checkup',
        isCompleted: true,
        priority: EisenhowerPriority.notUrgentImportant,
        plannedDate: DateTime.now().subtract(const Duration(days: 2)),
        createdDate: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Task(
        id: KeyHelper.generateStringId(),
        title: 'Review Morning Emails',
        description: 'Check and respond to priority emails from overnight',
        isCompleted: true,
        priority: EisenhowerPriority.urgentImportant,
        plannedDate: DateTime.now(),
        createdDate: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];
  }

  /// Demo notes to be created
  static List<Note> get notes => [
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Meeting Notes - Product Planning',
          content: '''# Product Planning Meeting

## Attendees
- John Doe (Product Manager)
- Jane Smith (Lead Developer)
- Mike Johnson (Designer)

## Key Points
- New feature roadmap for Q2
- User feedback analysis
- Technical requirements review

## Action Items
- [ ] Create wireframes for new dashboard
- [ ] Schedule user interviews
- [ ] Finalize API specifications
''',
          order: 1.0,
          createdDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Book Recommendations',
          content: '''# Books to Read

## Programming
- Clean Code by Robert Martin
- Design Patterns by Gang of Four
- The Pragmatic Programmer

## Business
- The Lean Startup
- Good to Great
- Atomic Habits

## Personal Development
- Mindset by Carol Dweck
- Deep Work by Cal Newport
''',
          order: 2.0,
          createdDate: DateTime.now().subtract(const Duration(days: 5)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Recipe - Healthy Smoothie',
          content: '''# Green Power Smoothie

## Ingredients
- 1 banana
- 1 cup spinach
- 1/2 avocado
- 1 cup almond milk
- 1 tbsp chia seeds
- 1 tsp honey

## Instructions
1. Add all ingredients to blender
2. Blend for 60 seconds
3. Serve immediately
4. Enjoy!

*Great for post-workout nutrition*
''',
          order: 3.0,
          createdDate: DateTime.now().subtract(const Duration(days: 8)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Travel Checklist',
          content: '''# Travel Preparation Checklist

## Documents
- [ ] Passport/ID
- [ ] Travel insurance
- [ ] Hotel reservations
- [ ] Flight tickets
- [ ] Visa (if required)

## Packing
- [ ] Clothes for weather
- [ ] Toiletries
- [ ] Medications
- [ ] Electronics & chargers
- [ ] Camera

## Before Leaving
- [ ] Notify bank of travel
- [ ] Set up mail hold
- [ ] Check weather forecast
- [ ] Download offline maps
''',
          order: 4.0,
          createdDate: DateTime.now().subtract(const Duration(days: 12)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Weekly Goals',
          content: '''# This Week's Goals

## Work
- [ ] Complete quarterly review
- [ ] Finish API documentation
- [ ] Team 1:1 meetings
- [ ] Code review backlog

## Personal
- [ ] Exercise 3 times
- [ ] Call family
- [ ] Read 2 chapters
- [ ] Meal prep Sunday

## Learning
- [ ] Flutter widget tutorial
- [ ] System design video
- [ ] Practice coding interview

## Health
- [ ] 8 hours sleep daily
- [ ] Drink 2L water
- [ ] Take vitamins
''',
          order: 5.0,
          createdDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Project Ideas',
          content: '''# App Project Ideas

## Productivity Apps
1. **Time Tracker Pro**
   - Pomodoro timer with analytics
   - Tag-based categorization
   - Export to CSV
   
2. **Habit Builder**
   - Streak tracking
   - Reminder notifications
   - Progress visualization

3. **Note Taking Plus**
   - Markdown support
   - Sync across devices
   - Search and tags

## Learning Projects
- Flutter desktop app
- REST API with Node.js
- Database design practice
- UI/UX design portfolio

## Side Business Ideas
- Freelance mobile development
- Online course creation
- Tech consulting
''',
          order: 6.0,
          createdDate: DateTime.now().subtract(const Duration(days: 6)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Investment Research',
          content: '''# Investment Portfolio Notes

## Current Holdings
- **Tech Stocks**: 40%
- **Index Funds**: 35%
- **Bonds**: 15%
- **Cash**: 10%

## Research Targets
1. Renewable energy ETFs
2. Emerging market funds
3. Real estate investment trusts
4. Cryptocurrency allocation

## Monthly Goals
- [ ] Increase emergency fund
- [ ] Rebalance portfolio
- [ ] Review expense tracking
- [ ] Research new opportunities

## Key Metrics to Watch
- Expense ratio < 0.1%
- Diversification across sectors
- Dollar-cost averaging schedule
''',
          order: 7.0,
          createdDate: DateTime.now().subtract(const Duration(days: 9)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Workout Routines',
          content: '''# Fitness Plan

## Monday - Upper Body
- Push-ups: 3x12
- Pull-ups: 3x8
- Dumbbell rows: 3x10
- Shoulder press: 3x10
- Planks: 3x60s

## Wednesday - Lower Body  
- Squats: 3x15
- Lunges: 3x12 each leg
- Deadlifts: 3x8
- Calf raises: 3x15
- Wall sit: 3x45s

## Friday - Full Body
- Burpees: 3x8
- Mountain climbers: 3x20
- Jumping jacks: 3x30
- Push-up to T: 3x8
- Cool down stretch: 10min

## Weekend - Cardio
- 30min walk/jog
- Bike ride
- Swimming
- Hiking
''',
          order: 8.0,
          createdDate: DateTime.now().subtract(const Duration(days: 4)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Learning Resources',
          content: '''# Online Learning Bookmarks

## Programming Courses
- **Udemy**: Advanced Flutter Development
- **Coursera**: System Design Fundamentals  
- **Pluralsight**: Clean Architecture
- **YouTube**: Tech conference talks

## Design & UX
- **Figma**: Community templates
- **Dribbble**: Design inspiration
- **Material Design**: Guidelines
- **Human Interface**: Apple's guide

## Career Development
- **LinkedIn Learning**: Leadership skills
- **Skillshare**: Creative workshops
- **TED Talks**: Innovation mindset
- **Podcasts**: Industry insights

## Free Resources
- GitHub repositories
- Medium articles
- Stack Overflow
- Documentation sites
''',
          order: 9.0,
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
        Note(
          id: KeyHelper.generateStringId(),
          title: 'Monthly Budget Review',
          content: '''# February Budget Analysis

## Income
- Salary: \$5,500
- Freelance: \$800
- **Total**: \$6,300

## Fixed Expenses
- Rent: \$1,200
- Insurance: \$300
- Phone: \$80
- Subscriptions: \$120
- **Subtotal**: \$1,700

## Variable Expenses
- Groceries: \$400
- Dining out: \$200
- Transportation: \$150
- Entertainment: \$100
- **Subtotal**: \$850

## Savings & Investments
- Emergency fund: \$500
- Retirement: \$800
- Investments: \$600
- **Total saved**: \$1,900

## Notes
- Exceeded dining budget by \$50
- Need to reduce subscription services
- On track for annual savings goal
''',
          order: 10.0,
          createdDate: DateTime.now().subtract(const Duration(days: 15)),
        ),
      ];

  /// Demo app usages for development and productivity tracking
  static List<AppUsage> get appUsages => [
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.whatsapp',
          displayName: 'WhatsApp',
          color: '25D366',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 6)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.instagram.android',
          displayName: 'Instagram',
          color: 'E4405F',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 5)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.google.android.youtube',
          displayName: 'YouTube',
          color: 'FF0000',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 4)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.spotify.music',
          displayName: 'Spotify',
          color: '1DB954',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.twitter.android',
          displayName: 'Twitter',
          color: '1DA1F2',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.google.android.gm',
          displayName: 'Gmail',
          color: 'EA4335',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
        AppUsage(
          id: KeyHelper.generateStringId(),
          name: 'com.udemy.android',
          displayName: 'Udemy',
          color: 'A435F0',
          deviceName: 'Mobile',
          createdDate: DateTime.now().subtract(const Duration(days: 7)),
        ),
      ];

  /// Demo habit records for showing progress
  /// Ensures exactly 2 habits appear as incomplete for today
  /// Creates rich historical data for statistics view
  static List<HabitRecord> generateHabitRecords(List<Habit> habits) {
    final records = <HabitRecord>[];
    final now = DateTime.now();

    // Generate extended progress for the meditation habit (first habit)
    // Make it NOT completed today to show on Today page (1st incomplete habit)
    if (habits.isNotEmpty) {
      final meditationHabit = habits[0];

      // Generate 365 days of historical data for rich statistics
      for (int i = 1; i < 365; i++) {
        final recordDate = now.subtract(Duration(days: i));

        // Create realistic patterns with good streaks and some gaps
        bool shouldComplete = false;

        // Year-long journey with different phases
        if (i >= 335) {
          // First month (days 335-365) - enthusiastic start (90% completion)
          shouldComplete = i % 10 != 0 && i % 7 != 6; // Miss every 10th and Saturdays
        } else if (i >= 280) {
          // Months 2-3 (days 280-335) - reality hits (70% completion)
          shouldComplete = i % 7 != 0 && i % 5 != 1 && i % 11 != 0;
        } else if (i >= 210) {
          // Months 4-5 (days 210-280) - building consistency (75% completion)
          shouldComplete = i % 6 != 0 && i % 9 != 1;
        } else if (i >= 140) {
          // Months 6-8 (days 140-210) - strong habit formed (85% completion)
          shouldComplete = i % 8 != 0 && i % 13 != 2;
        } else if (i >= 70) {
          // Months 9-10 (days 70-140) - occasional breaks (80% completion)
          shouldComplete = i % 7 != 0 && i % 12 != 0;
        } else if (i >= 35) {
          // Month 11 (days 35-70) - some struggles (65% completion)
          shouldComplete = i % 5 != 0 && i % 3 != 1 && i % 8 != 2;
        } else {
          // Recent month (days 0-35) - renewed focus (80% completion)
          shouldComplete = i % 6 != 0 && i % 13 != 0;
        }

        if (shouldComplete) {
          records.add(HabitRecord(
            id: KeyHelper.generateStringId(),
            habitId: meditationHabit.id,
            date: recordDate,
            createdDate: recordDate,
          ));
        }
      }
    }

    // Generate extended progress for the reading habit (second habit)
    // Make it completed today (not show as incomplete on Today page)
    if (habits.length > 1) {
      final readingHabit = habits[1];

      // Generate 365 days of data for this habit
      for (int i = 0; i < 365; i++) {
        final recordDate = now.subtract(Duration(days: i));

        // Create very consistent pattern (daily habit with seasonal variations)
        bool shouldComplete = false;

        // Year-long consistent reading with life interruptions
        if (i < 7) {
          // This week - complete most days including today (85%)
          shouldComplete = i % 4 != 3;
        } else if (i >= 28 && i < 35) {
          // Break week 4 weeks ago (vacation)
          shouldComplete = false;
        } else if (i >= 90 && i < 104) {
          // Two-week break 3 months ago (busy period)
          shouldComplete = i % 7 == 0; // Only weekends
        } else if (i >= 200 && i < 207) {
          // Another break 7 months ago
          shouldComplete = false;
        } else if (i >= 300 && i < 314) {
          // Holiday break 10 months ago
          shouldComplete = i % 5 == 0; // Sporadic
        } else {
          // Regular excellent performance (90% completion)
          shouldComplete = i % 10 != 0;
        }

        if (shouldComplete) {
          records.add(HabitRecord(
            id: KeyHelper.generateStringId(),
            habitId: readingHabit.id,
            date: recordDate,
            createdDate: recordDate,
          ));
        }
      }
    }

    // Generate progress for exercise habit (third habit)
    // Make it completed today (not show as incomplete on Today page)
    if (habits.length > 2) {
      final exerciseHabit = habits[2];

      // Generate 365 days of data for this 3x/week habit
      for (int i = 0; i < 365; i++) {
        final recordDate = now.subtract(Duration(days: i));
        final weekday = recordDate.weekday; // 1=Monday, 7=Sunday

        bool shouldComplete = false;

        // This is a Mon-Wed-Fri habit with seasonal patterns
        if (weekday == 1 || weekday == 3 || weekday == 5) {
          if (i == 0) {
            // Always complete today if it's a scheduled day
            shouldComplete = true;
          } else if (i < 14) {
            // Recent 2 weeks - very good adherence (95%)
            shouldComplete = i % 20 != 0;
          } else if (i >= 60 && i < 90) {
            // Winter slowdown 2-3 months ago (60% adherence)
            shouldComplete = i % 5 != 0 && i % 3 != 1;
          } else if (i >= 150 && i < 180) {
            // Summer vacation period 5-6 months ago (70% adherence)
            shouldComplete = i % 4 != 0 && i % 7 != 2;
          } else if (i >= 300 && i < 330) {
            // Initial establishment period 10-11 months ago (75% adherence)
            shouldComplete = i % 6 != 0 && i % 9 != 1;
          } else {
            // Normal good performance throughout the year (85%)
            shouldComplete = i % 7 != 0;
          }
        } else if (i == 0) {
          // Complete today even if it's not a scheduled day (to not show on Today page)
          shouldComplete = true;
        }

        if (shouldComplete) {
          records.add(HabitRecord(
            id: KeyHelper.generateStringId(),
            habitId: exerciseHabit.id,
            date: recordDate,
            createdDate: recordDate,
          ));
        }
      }
    }

    // Generate progress for water drinking habit (fourth habit)
    // Make it NOT completed today to show on Today page (2nd incomplete habit)
    if (habits.length > 3) {
      final waterHabit = habits[3];

      // Generate 180 days of data (6-month habit)
      for (int i = 1; i < 180; i++) {
        // Start from i=1 to skip today
        final recordDate = now.subtract(Duration(days: i));

        // This habit was started 6 months ago with improving consistency
        bool shouldComplete = false;

        if (i < 30) {
          // Recent month - building strong consistency (75%)
          shouldComplete = i % 4 != 0 && i % 7 != 1;
        } else if (i < 60) {
          // Month 2 - finding rhythm (65%)
          shouldComplete = i % 5 != 0 && i % 3 != 1;
        } else if (i < 90) {
          // Month 3 - middle period struggles (55%)
          shouldComplete = i % 6 != 0 && i % 2 != 1 && i % 9 != 3;
        } else if (i < 120) {
          // Month 4 - renewed effort (70%)
          shouldComplete = i % 5 != 0 && i % 8 != 2;
        } else if (i < 150) {
          // Month 5 - getting better (60%)
          shouldComplete = i % 7 != 0 && i % 4 != 2;
        } else {
          // First month - enthusiastic start but sporadic (45%)
          shouldComplete = i % 8 != 0 && i % 3 == 0 && i % 11 != 5;
        }

        if (shouldComplete) {
          records.add(HabitRecord(
            id: KeyHelper.generateStringId(),
            habitId: waterHabit.id,
            date: recordDate,
            createdDate: recordDate,
          ));
        }
      }
    }

    // Generate progress for vitamins habit (fifth habit)
    // Make it completed today (not show as incomplete on Today page)
    if (habits.length > 4) {
      final vitaminsHabit = habits[4];

      // Generate 90 days of data (3-month habit)
      for (int i = 0; i < 90; i++) {
        final recordDate = now.subtract(Duration(days: i));

        // Newer habit with excellent momentum
        bool shouldComplete = false;

        if (i < 7) {
          // This week - excellent including today (95%)
          shouldComplete = i != 3; // Miss one day this week
        } else if (i < 30) {
          // Recent month - very good (85%)
          shouldComplete = i % 6 != 0 && i % 11 != 2;
        } else if (i < 60) {
          // Month 2 - building habit (80%)
          shouldComplete = i % 5 != 0 && i % 9 != 1;
        } else {
          // First month - enthusiastic start (90%)
          shouldComplete = i % 8 != 0 && i % 13 != 3;
        }

        if (shouldComplete) {
          records.add(HabitRecord(
            id: KeyHelper.generateStringId(),
            habitId: vitaminsHabit.id,
            date: recordDate,
            createdDate: recordDate,
          ));
        }
      }
    }

    // Generate progress for journaling habit (sixth habit)
    // Make it completed today (not show as incomplete on Today page)
    if (habits.length > 5) {
      final journalHabit = habits[5];

      // Generate 365 days of data (year-long habit)
      for (int i = 0; i < 365; i++) {
        final recordDate = now.subtract(Duration(days: i));

        // Evening habit with long-term consistency and life phases
        bool shouldComplete = false;

        if (i < 30) {
          // Recent month including today - very consistent (85%)
          // Make sure today (i=0) is completed to not show on Today page
          if (i == 0) {
            shouldComplete = true;
          } else {
            shouldComplete = i % 7 != 0 && i % 12 != 3;
          }
        } else if (i >= 60 && i < 90) {
          // Break period 2-3 months ago (busy work period)
          shouldComplete = i % 5 == 0; // Only occasional entries
        } else if (i >= 150 && i < 170) {
          // Another break 5-6 months ago (vacation)
          shouldComplete = i % 4 == 0;
        } else if (i >= 270 && i < 290) {
          // Major life event 9 months ago (moving)
          shouldComplete = i % 10 == 0; // Very sporadic
        } else if (i >= 330) {
          // Initial establishment (first month)
          shouldComplete = i % 6 != 0 && i % 8 != 2; // 70% as building habit
        } else {
          // General good performance throughout the year (75%)
          shouldComplete = i % 5 != 0 && i % 9 != 1;
        }

        if (shouldComplete) {
          records.add(HabitRecord(
            id: KeyHelper.generateStringId(),
            habitId: journalHabit.id,
            date: recordDate,
            createdDate: recordDate,
          ));
        }
      }
    }

    return records;
  }

  /// Demo task time records for showing time tracking
  static List<TaskTimeRecord> generateTaskTimeRecords(List<Task> tasks) {
    final records = <TaskTimeRecord>[];
    final now = DateTime.now();

    // Add time records for some tasks, including today's activity
    if (tasks.isNotEmpty) {
      // Project proposal task (first task)
      final projectTask = tasks[0];
      records.addAll([
        TaskTimeRecord(
          id: KeyHelper.generateStringId(),
          taskId: projectTask.id,
          duration: 3600, // 1 hour in seconds
          createdDate: now.subtract(const Duration(days: 1)),
        ),
        TaskTimeRecord(
          id: KeyHelper.generateStringId(),
          taskId: projectTask.id,
          duration: 5400, // 1.5 hours in seconds
          createdDate: now.subtract(const Duration(hours: 3)),
        ),
        // Add time for today
        TaskTimeRecord(
          id: KeyHelper.generateStringId(),
          taskId: projectTask.id,
          duration: 2700, // 45 minutes in seconds
          createdDate: now.subtract(const Duration(hours: 1)),
        ),
      ]);

      // Add time records for microservices learning task (if it exists)
      if (tasks.length > 4) {
        final microservicesLearningTask = tasks[4]; // "Learn Microservices Architecture Patterns"
        records.add(TaskTimeRecord(
          id: KeyHelper.generateStringId(),
          taskId: microservicesLearningTask.id,
          duration: 2700, // 45 minutes in seconds
          createdDate: now.subtract(const Duration(minutes: 45)),
        ));
      }

      // Add time records for code review task (if it exists)
      if (tasks.length > 6) {
        final codeReviewTask = tasks[6]; // "Review Code Changes"
        records.addAll([
          TaskTimeRecord(
            id: KeyHelper.generateStringId(),
            taskId: codeReviewTask.id,
            duration: 1800, // 30 minutes in seconds
            createdDate: now.subtract(const Duration(hours: 2)),
          ),
          TaskTimeRecord(
            id: KeyHelper.generateStringId(),
            taskId: codeReviewTask.id,
            duration: 1200, // 20 minutes in seconds
            createdDate: now.subtract(const Duration(minutes: 45)),
          ),
        ]);
      }

      // Add time for learning task to show variety
      if (tasks.length > 2) {
        final learningTask = tasks[2]; // "Learn Flutter State Management"
        records.add(TaskTimeRecord(
          id: KeyHelper.generateStringId(),
          taskId: learningTask.id,
          duration: 2400, // 40 minutes in seconds
          createdDate: now.subtract(const Duration(days: 1, hours: 2)),
        ));
      }

      // Add time for the completed "Study Design Patterns" learning task (for today's tag chart)
      if (tasks.length > 14) {
        final designPatternsTask = tasks[14]; // "Study Design Patterns"
        records.addAll([
          TaskTimeRecord(
            id: KeyHelper.generateStringId(),
            taskId: designPatternsTask.id,
            duration: 3600, // 1 hour in seconds - learning session
            createdDate: now.subtract(const Duration(hours: 3)),
          ),
          TaskTimeRecord(
            id: KeyHelper.generateStringId(),
            taskId: designPatternsTask.id,
            duration: 2700, // 45 minutes in seconds - practice session
            createdDate: now.subtract(const Duration(hours: 1)),
          ),
          TaskTimeRecord(
            id: KeyHelper.generateStringId(),
            taskId: designPatternsTask.id,
            duration: 1800, // 30 minutes in seconds - review and notes
            createdDate: now.subtract(const Duration(minutes: 30)),
          ),
        ]);
      }

      // Add time for the "Learn API Documentation" learning task (for today's tag chart)
      if (tasks.length > 15) {
        final apiDocTask = tasks[15]; // "Learn API Documentation"
        records.addAll([
          TaskTimeRecord(
            id: KeyHelper.generateStringId(),
            taskId: apiDocTask.id,
            duration: 2400, // 40 minutes in seconds - reading documentation
            createdDate: now.subtract(const Duration(hours: 4)),
          ),
          TaskTimeRecord(
            id: KeyHelper.generateStringId(),
            taskId: apiDocTask.id,
            duration: 1500, // 25 minutes in seconds - practice examples
            createdDate: now.subtract(const Duration(hours: 2)),
          ),
        ]);
      }
    }

    return records;
  }

  /// Generates app usage time records for demo app usages
  /// Creates realistic usage patterns with distinct periods for comparison feature
  static List<AppUsageTimeRecord> generateAppUsageTimeRecords(List<AppUsage> appUsages) {
    final records = <AppUsageTimeRecord>[];
    final now = DateTime.now();

    // Generate usage records for the past 45 days to support rich comparison
    for (int dayOffset = 0; dayOffset < 45; dayOffset++) {
      final usageDate = now.subtract(Duration(days: dayOffset));
      final weekday = usageDate.weekday; // 1=Monday, 7=Sunday

      // Create distinct usage patterns for different periods:
      // Recent period (0-14 days): Higher usage, different patterns
      // Previous period (15-29 days): Moderate usage baseline
      // Older period (30-44 days): Lower usage, establishing patterns
      final isRecentPeriod = dayOffset < 15;
      final isPreviousPeriod = dayOffset >= 15 && dayOffset < 30;
      final isOlderPeriod = dayOffset >= 30;

      for (final appUsage in appUsages) {
        int duration = 0;

        switch (appUsage.name) {
          case 'com.whatsapp':
            // WhatsApp - Daily communication
            if (isRecentPeriod) {
              // Recent: Increased communication (holidays/busy period)
              duration = weekday <= 5
                  ? 3600 + (dayOffset * 50)
                  : 2700 + (dayOffset * 40); // 60-90min weekdays, 45-75min weekends
            } else if (isPreviousPeriod) {
              // Previous: Normal baseline usage
              duration = weekday <= 5
                  ? 2400 + (dayOffset * 30)
                  : 1800 + (dayOffset * 25); // 40-55min weekdays, 30-45min weekends
            } else if (isOlderPeriod) {
              // Older: Lower usage when forming habit
              duration = weekday <= 5
                  ? 1800 + (dayOffset * 20)
                  : 1200 + (dayOffset * 15); // 30-45min weekdays, 20-35min weekends
            }
            break;

          case 'com.instagram.android':
            // Instagram - Social browsing with weekend spikes
            if (isRecentPeriod) {
              // Recent: High social media engagement
              duration = weekday > 5
                  ? 4200 + (dayOffset * 60)
                  : 2100 + (dayOffset * 40); // 70-90min weekends, 35-55min weekdays
            } else if (isPreviousPeriod) {
              // Previous: Moderate usage
              duration = weekday > 5
                  ? 2700 + (dayOffset * 40)
                  : 1500 + (dayOffset * 25); // 45-65min weekends, 25-40min weekdays
            } else if (isOlderPeriod) {
              // Older: Lower usage
              duration = weekday > 5
                  ? 1800 + (dayOffset * 30)
                  : 900 + (dayOffset * 20); // 30-50min weekends, 15-30min weekdays
            }
            break;

          case 'com.google.android.youtube':
            // YouTube - Entertainment with evening peaks
            if (isRecentPeriod) {
              // Recent: Binge-watching period
              duration = weekday > 5
                  ? 7200 + (dayOffset * 120)
                  : 4800 + (dayOffset * 80); // 2-3.5hours weekends, 80-140min weekdays
            } else if (isPreviousPeriod) {
              // Previous: Regular entertainment
              duration = weekday > 5
                  ? 4800 + (dayOffset * 80)
                  : 3000 + (dayOffset * 50); // 80-160min weekends, 50-90min weekdays
            } else if (isOlderPeriod) {
              // Older: Moderate consumption
              duration = weekday > 5
                  ? 3600 + (dayOffset * 60)
                  : 2200 + (dayOffset * 35); // 60-120min weekends, 35-70min weekdays
            }
            break;

          case 'com.spotify.music':
            // Spotify - Background music during work/activities
            if (isRecentPeriod) {
              // Recent: Work from home period with more music
              duration = weekday <= 5
                  ? 5400 + (dayOffset * 100)
                  : 3600 + (dayOffset * 60); // 90-180min weekdays, 60-120min weekends
            } else if (isPreviousPeriod) {
              // Previous: Normal work schedule
              duration = weekday <= 5
                  ? 3600 + (dayOffset * 60)
                  : 2400 + (dayOffset * 40); // 60-120min weekdays, 40-80min weekends
            } else if (isOlderPeriod) {
              // Older: Less consistent usage
              duration = weekday <= 5
                  ? 2700 + (dayOffset * 45)
                  : 1800 + (dayOffset * 30); // 45-90min weekdays, 30-60min weekends
            }
            break;

          case 'com.twitter.android':
            // Twitter - News and social updates with current events spikes
            if (isRecentPeriod) {
              // Recent: High news consumption period
              duration = weekday <= 5
                  ? 2400 + (dayOffset * 50)
                  : 1800 + (dayOffset * 35); // 40-75min weekdays, 30-55min weekends
            } else if (isPreviousPeriod) {
              // Previous: Normal news checking
              duration = weekday <= 5
                  ? 1500 + (dayOffset * 30)
                  : 1080 + (dayOffset * 25); // 25-45min weekdays, 18-35min weekends
            } else if (isOlderPeriod) {
              // Older: Lighter usage
              duration = weekday <= 5
                  ? 900 + (dayOffset * 20)
                  : 600 + (dayOffset * 15); // 15-30min weekdays, 10-22min weekends
            }
            break;

          case 'com.google.android.gm':
            // Gmail - Professional email with workday patterns
            if (isRecentPeriod) {
              // Recent: Busy work period
              duration = weekday <= 5
                  ? 1800 + (dayOffset * 40)
                  : 600 + (dayOffset * 15); // 30-60min weekdays, 10-20min weekends
            } else if (isPreviousPeriod) {
              // Previous: Normal work email
              duration = weekday <= 5
                  ? 1200 + (dayOffset * 25)
                  : 360 + (dayOffset * 10); // 20-40min weekdays, 6-15min weekends
            } else if (isOlderPeriod) {
              // Older: Establishing email routine
              duration =
                  weekday <= 5 ? 900 + (dayOffset * 20) : 240 + (dayOffset * 8); // 15-30min weekdays, 4-12min weekends
            }
            break;

          case 'com.udemy.android':
            // Udemy - Learning sessions with goal-oriented patterns
            if (isRecentPeriod) {
              // Recent: Intensive learning period (new course started)
              duration = (weekday == 1 || weekday == 3 || weekday == 5 || weekday == 6)
                  ? 5400 + (dayOffset * 90)
                  : 0; // 90-180min on learning days
            } else if (isPreviousPeriod) {
              // Previous: Consistent learning routine
              duration = (weekday == 1 || weekday == 3 || weekday == 6)
                  ? 3600 + (dayOffset * 60)
                  : 0; // 60-120min on learning days
            } else if (isOlderPeriod) {
              // Older: Building learning habit
              duration = (weekday == 6 || weekday == 7) ? 2700 + (dayOffset * 45) : 0; // 45-90min on weekends only
            }
            break;
        }

        // Add some randomness to make it more realistic
        final randomFactor = (dayOffset % 7) / 10.0; // 0-0.6 multiplier
        duration = (duration * (0.7 + randomFactor)).round();

        // Skip some days randomly to create realistic gaps
        final shouldSkip = (dayOffset % 11 == 0 && appUsage.name != 'com.google.android.gm') ||
            (dayOffset % 13 == 0 && appUsage.name == 'com.udemy.android');

        if (duration > 0 && !shouldSkip) {
          records.add(AppUsageTimeRecord(
            id: KeyHelper.generateStringId(),
            appUsageId: appUsage.id,
            duration: duration,
            usageDate: usageDate,
            createdDate: usageDate,
          ));
        }
      }
    }

    return records;
  }
}
