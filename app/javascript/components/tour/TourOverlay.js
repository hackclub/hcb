import React, { useEffect, useState } from 'react'
import PropTypes from 'prop-types'
import TourStep from './TourStep'
import csrf from '../../common/csrf'

const tours = {
  welcome(options) {
    const steps = []

    const isMobile = window.matchMedia('(max-width: 56em)').matches

    if (options.initial || options.demo) {
      steps.push({
        attachTo: 'invite',
        text: `Invite others to your ${
          options.demo ? 'demo' : 'new'
        } organization. It's like multiplayer banking!`,
        placement: isMobile ? 'bottom' : 'right',
      })
    }

    if (!options.demo) {
      steps.push({
        attachTo: isMobile ? 'spend' : 'cards',
        text: 'Instantly issue a virtual HCB card for yourself. Gotta spend that 💸!',
        placement: isMobile ? 'top' : 'right',
        strategy: 'fixed',
      })

      steps.push({
        attachTo: isMobile ? 'receive' : 'donations',
        text: 'Share your donation form with others and embed it on your website.',
        placement: isMobile ? 'top-end' : 'right',
        strategy: 'fixed',
      })

      if (!isMobile) {
        steps.push({
          attachTo: 'perks',
          text: 'Get access to free tools for things like sending newsletters and managing team passwords. Stickers included.',
          strategy: 'fixed',
        })
      }
    } else {
      steps.push({
        attachTo: 'playground_mode',
        text: "You're in Playground Mode— a HCB staff member will reach out shortly to get you set up.",
        placement: 'bottom',
      })
    }

    return steps
  },
}

function TourOverlay(props) {
  const [currentStep, setCurrentStep] = useState(props.step)

  const tour = props.tour && tours[props.tour](props.options)

  useEffect(() => {
    ;(async () => {
      if (props.tour && currentStep < tour.length) {
        await fetch(`/tours/${props.id}/set_step`, {
          method: 'POST',
          headers: {
            'X-CSRF-Token': csrf(),
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ step: currentStep }),
        })
      }
    })()
  }, [currentStep])

  return (
    <div>
      {tour &&
        tour.map((step, index) => (
          <TourStep
            key={index}
            text={step.text}
            attachTo={`[data-tour-step='${step.attachTo}']`}
            placement={step.placement ?? 'right'}
            strategy={step.strategy}
            last={index == tour.length - 1}
            visible={index == currentStep}
            stepIndex={index}
            stepCount={tour.length}
            tourId={props.id}
            onNext={() => {
              if (currentStep + 1 >= tour.length) {
                fetch(`/tours/${props.id}/mark_complete`, {
                  method: 'POST',
                  headers: {
                    'X-CSRF-Token': csrf(),
                  },
                })
              }

              setCurrentStep(currentStep + 1)
            }}
            onSkip={() => {
              setCurrentStep(null)

              fetch(`/tours/${props.id}/mark_complete`, {
                method: 'POST',
                headers: {
                  'X-CSRF-Token': csrf(),
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({ cancelled: true }),
              })
            }}
          />
        ))}

      {props.backToTour && (
        <a
          href={props.backToTour}
          className="flex items-center text-decoration-none card back-to-tour"
        >
          Continue tour <span className="ml1 back-to-tour__arrow">→</span>
        </a>
      )}
    </div>
  )
}

TourOverlay.propTypes = {
  step: PropTypes.number,
  id: PropTypes.number,
  options: PropTypes.object,
  tour: PropTypes.string,
  backToTour: PropTypes.string,
}

export default TourOverlay
