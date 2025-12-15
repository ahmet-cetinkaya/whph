import 'package:whph/core/domain/features/notes/note.dart';
import 'package:whph/core/application/shared/utils/key_helper.dart';

/// Demo note data generator
class DemoNotes {
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
}
