function submitQuiz(moduleId) {
  const selected = document.querySelector('input[name="q1"]:checked');
  if (!selected) {
    alert("Please select an answer first.");
    return;
  }

  const payload = {
    module: moduleId,
    score: selected.value,
    timestamp: new Date().toISOString()
  };

  fetch("/ui-api/save_score", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  })
    .then(r => r.json())
    .then(() => {
      alert("Your score has been submitted! You can view it on your dashboard.");
      window.location.href = "dashboard.html";
    })
    .catch(() => {
      alert("We could not submit your score. Please try again later.");
    });
}
