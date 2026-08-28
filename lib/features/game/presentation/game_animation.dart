Duration gameAnimationDuration(bool reduceMotion, Duration normal) =>
    reduceMotion ? Duration.zero : normal;
