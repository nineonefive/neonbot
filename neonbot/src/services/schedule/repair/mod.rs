use std::{
    collections::{BinaryHeap, HashMap},
    time::Duration,
};

use crate::types::{EventType, PremierEvent, PremierSchedule};
use chrono::{Datelike, NaiveDate, TimeZone, Utc, Weekday};
use chrono_tz::Tz;

/// Represents a candidate sequence of premier events and its associated likelihood
#[derive(Debug, Clone, PartialEq)]
struct EventChain<'a, T: TimeZone = Utc> {
    /// The sequence of events in this chain
    events: Vec<&'a PremierEvent<T>>,

    /// The likelihood of this chain being valid under our rules
    likelihood: f64,
}

impl Ord for EventChain<'_, Tz> {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.likelihood
            .partial_cmp(&other.likelihood)
            .unwrap_or(std::cmp::Ordering::Equal)
    }
}

impl PartialOrd for EventChain<'_, Tz> {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(
            self.likelihood
                .partial_cmp(&other.likelihood)
                .unwrap_or(std::cmp::Ordering::Equal),
        )
    }
}

impl Eq for EventChain<'_, Tz> {}

// Logic to repair the schedule from riot's garbage data
// idk if this is correct for other regions, plz help 🥺

/// Attempts to repair a schedule from Riot's API.
///
/// Assumptions:
///  - At most one event can be scheduled per day
///  - The season should end on a Tournament
///  - Currently follows the Us East timezone schedule of `S/M/S/M/{M,T}` starting
///    on wednesdays
///  - That beam search and conditional probabilities can save us from the nonsense Riot gives
pub fn repair(schedule: &PremierSchedule, tz: Tz) -> PremierSchedule {
    // the events localized to the given timezone
    let localized_events = schedule
        .events
        .iter()
        .map(|e| e.localize(tz))
        .collect::<Vec<_>>();

    // Group them by date
    let mut grouped_events: HashMap<NaiveDate, Vec<&PremierEvent<Tz>>> = HashMap::new();
    localized_events
        .iter()
        .map(|e| (e.starts_at.date_naive(), e))
        .for_each(|(date, event)| {
            grouped_events.entry(date).or_default().push(event);
        });

    // Now put them into consecutive buckets for beam search, one bucket per day
    let mut buckets = grouped_events.into_iter().collect::<Vec<_>>();
    buckets.sort_by_key(|(date, _)| *date);

    let chain = beam_search(buckets.as_slice(), 3);
    if chain.is_empty() {
        return schedule.clone();
    }

    PremierSchedule {
        events: chain
            .into_iter()
            .map(|e| e.to_utc())
            .collect::<Vec<PremierEvent>>(),
        championship_points_required: schedule.championship_points_required,
        starts_at: schedule.starts_at,
        ends_at: schedule.ends_at,
    }
}

/// Returns the likelihood `P(x_{t+1} | x_{1:t})`
///
/// If `is_last` is `true`, this applies a terminal likelihood adjustment so the final
/// result is `P_term * P(x_{1:t+1})`
fn likelihood_model(chain: &[&PremierEvent<Tz>], el: &PremierEvent<Tz>, is_last: bool) -> f64 {
    let weekday = el.starts_at.weekday();

    // Simple checks
    match weekday {
        Weekday::Wed | Weekday::Fri => {
            if el.event_type != EventType::Scrim {
                return 0.0;
            }
        }
        Weekday::Thu | Weekday::Sat => {
            if el.event_type != EventType::League {
                return 0.0;
            }
        }
        Weekday::Sun => {
            if el.event_type == EventType::Scrim {
                return 0.0;
            }
        }
        _ => return 0.0,
    };

    // Sometimes riot gives scrim/match events that only last 15m which is obviously not right. However,
    // it's correct for tournaments since their queue window is only 15m.
    if el.duration() < Duration::from_hours(1) && el.event_type != EventType::Tournament {
        return 0.0;
    }

    // All sequences end with a tournament
    if is_last {
        match el.event_type {
            EventType::Tournament => return 1.0,
            _ => return 0.0,
        };
    }

    1.0
}

fn beam_search<'a, 'b: 'a>(
    buckets: &'a [(NaiveDate, Vec<&'b PremierEvent<Tz>>)],
    beam_width: usize,
) -> Vec<&'b PremierEvent<Tz>> {
    let mut beam: Vec<EventChain<'_, Tz>> = buckets[0]
        .1
        .iter()
        .map(|&e| EventChain {
            events: vec![e],
            likelihood: likelihood_model(&[], e, false),
        })
        .collect();

    for bucket in &buckets[1..] {
        let is_last = bucket == buckets.last().unwrap();
        let mut next_generation = BinaryHeap::<EventChain<'_, Tz>>::new();
        for &candidate in bucket.1.iter() {
            for chain in &beam {
                let mut new_events = chain.events.clone();
                new_events.push(candidate);
                let likelihood = likelihood_model(&chain.events, candidate, is_last);
                next_generation.push(EventChain {
                    events: new_events,
                    likelihood: likelihood * chain.likelihood,
                });
            }
        }

        beam.clear();
        beam.extend(next_generation.into_iter().take(beam_width));
    }

    beam.into_iter()
        .max_by(|a, b| {
            a.likelihood
                .partial_cmp(&b.likelihood)
                .unwrap_or(std::cmp::Ordering::Equal)
        })
        .map(|c| c.events)
        .unwrap_or_default()
}
