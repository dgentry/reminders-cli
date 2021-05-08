import EventKit

private let store = EKEventStore()
private let df = DateFormatter()

final class Reminders {
    func requestAccess(completion: @escaping (_ granted: Bool) -> Void) {
        store.requestAccess(to: .reminder) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func showLists() {
        let calendars = self.getCalendars()
        for calendar in calendars {
            print(calendar.title)
        }
    }

    func showListItems(withName name: String, isComplete: Bool) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)
        df.dateStyle = .short

        self.reminders(onCalendar: calendar, itemComplete:isComplete) { reminders in
            for (i, r) in reminders.enumerated() {
                print(isComplete ? df.string(from: r.completionDate!) : "", i, String(r.title))
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func complete(itemAtIndex index: Int, onListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(onCalendar: calendar, itemComplete:false) { reminders in
            guard let reminder = reminders[safe: index] else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            do {
                reminder.isCompleted = true
                try store.save(reminder, commit: true)
                print("Completed '\(reminder.title!)'")
            } catch let error {
                print("Failed to save reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func addReminder(string: String, toListNamed name: String) {
        let calendar = self.calendar(withName: name)
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.title = string

        do {
            try store.save(reminder, commit: true)
            print("Added '\(reminder.title!)' to '\(calendar.title)'")
        } catch let error {
            print("Failed to save reminder with error: \(error)")
            exit(1)
        }
    }

    // MARK: - Private functions

    private func reminders(onCalendar calendar: EKCalendar,
                                      itemComplete: Bool,
                                      completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let myPredicate = store.predicateForReminders(in: [calendar])
        store.fetchReminders(matching: myPredicate) { reminders in
            let r = reminders? .filter { $0.isCompleted == itemComplete }
            completion(r ?? [])
        }
    }

    private func calendar(withName name: String) -> EKCalendar {
        if let calendar = self.getCalendars().find(where: { $0.title.lowercased() == name.lowercased() }) {
            return calendar
        } else {
            print("No reminders list matching \(name)")
            exit(1)
        }
    }

    private func getCalendars() -> [EKCalendar] {
        return store.calendars(for: .reminder)
                    .filter { $0.allowsContentModifications }
    }
}
