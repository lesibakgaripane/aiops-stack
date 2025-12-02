document.addEventListener("DOMContentLoaded", function () {
  var form = document.getElementById("aw-quiz-form");
  var resultEl = document.getElementById("aw-quiz-result");

  if (!form || !resultEl) {
    return;
  }

  form.addEventListener("submit", function (event) {
    event.preventDefault();
    var score = 0;
    var total = 0;

    // Each question is a radio group with data-correct="value"
    var questions = form.querySelectorAll("[data-question]");
    questions.forEach(function (q) {
      total += 1;
      var correct = q.getAttribute("data-correct");
      var checked = q.querySelector("input[type='radio']:checked");
      if (checked && checked.value === correct) {
        score += 1;
      }
    });

    if (total === 0) {
      resultEl.textContent = "No questions found.";
      return;
    }

    var percent = Math.round((score / total) * 100);

    if (percent === 100) {
      resultEl.textContent =
        "Perfect (" + score + "/" + total + ") - excellent awareness!";
    } else if (percent >= 60) {
      resultEl.textContent =
        "Good (" + score + "/" + total + ") - you are on the right track, keep sharpening your awareness.";
    } else {
      resultEl.textContent =
        "(" + score + "/" + total + ") - time to improve. Review your organisation security guidance and try again.";
    }
  });
});
