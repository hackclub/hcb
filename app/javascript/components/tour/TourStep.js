import React, { useEffect, useLayoutEffect, useMemo, useRef } from 'react'
import PropTypes from 'prop-types'
import {
  useFloating,
  autoUpdate,
  offset,
  arrow,
  shift,
} from '@floating-ui/react-dom'
import Icon from '@hackclub/icons'
import clsx from 'clsx'

function TourStep({
  text,
  attachTo,
  placement,
  onNext,
  onSkip,
  last = false,
  visible = false,
  stepIndex,
  stepCount,
  ...props
}) {
  const arrowRef = useRef(null)

  const {
    x,
    y,
    reference,
    floating,
    strategy,
    middlewareData: { arrow: { x: arrowX, y: arrowY } = {} },
    refs,
  } = useFloating({
    whileElementsMounted: autoUpdate,
    placement,
    strategy: props.strategy,
    middleware: [
      offset(14),
      shift({ padding: 5 }),
      arrow({ element: arrowRef }),
    ],
  })

  useLayoutEffect(() => {
    reference(
      typeof attachTo == 'string' ? document.querySelector(attachTo) : attachTo
    )
  }, [reference, attachTo])

  useEffect(() => {
    if (visible) {
      refs.floating.current.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      })
    }
  }, [visible])

  const staticSide = useMemo(
    () =>
      ({
        top: 'bottom',
        right: 'left',
        bottom: 'top',
        left: 'right',
      })[placement.split('-')[0]],
    [placement]
  )

  // useEffect(() => {
  //   const onClick = async e => {
  //     if (visible) {
  //       // attempt to advance the backend to the next step
  //       // this is somewhat unreliable

  //       if (stepIndex + 1 >= stepCount) {
  //         await fetch(`/tours/${tourId}/mark_complete`, {
  //           method: 'POST',
  //           headers: {
  //             'X-CSRF-Token': csrf(),
  //             'Content-Type': 'application/json'
  //           }
  //         })
  //       } else {
  //         await fetch(`/tours/${tourId}/set_step`, {
  //           method: 'POST',
  //           headers: {
  //             'X-CSRF-Token': csrf(),
  //             'Content-Type': 'application/json'
  //           },
  //           body: JSON.stringify({ step: stepIndex + 1 })
  //         })
  //       }
  //     }
  //   }

  //   document.querySelector(attachTo)?.addEventListener('click', onClick)

  //   return () => {
  //     document.querySelector(attachTo)?.removeEventListener('click', onClick)
  //   }
  // }, [])

  return (
    <div
      className="card border b--info overflow-visible z-[2] max-w-96"
      ref={floating}
      style={{
        position: strategy,
        left: x ?? 0,
        top: y ?? 0,
        transition:
          'opacity 0.25s ease-out, visibility 0.25s ease-out, transform 0.25s ease-out',
        visibility: visible ? 'visible' : 'hidden',
        opacity: visible ? 1 : 0,
        transform: visible ? 'none' : 'translateY(10px)',
        width: 'calc(100vw - 10px)',
        zIndex: 150,
      }}
    >
      <div
        className={clsx(
          (staticSide == 'left' || staticSide == 'top') && 'border-left',
          (staticSide == 'left' || staticSide == 'bottom') && 'border-bottom',
          (staticSide == 'right' || staticSide == 'bottom') && 'border-right',
          (staticSide == 'right' || staticSide == 'top') && 'border-top',
          'b--info',
          'arrow'
        )}
        ref={arrowRef}
        style={{
          position: 'absolute',
          left: arrowX != null ? `${arrowX}px` : '',
          top: arrowY != null ? `${arrowY}px` : '',
          right: '',
          bottom: '',
          [staticSide]: '-9px',
        }}
      ></div>

      <button
        className="pop border-none cursor-pointer muted"
        style={{
          position: 'absolute',
          top: '0.5rem',
          right: '0.5rem',
          width: 28,
          height: 28,
        }}
        onClick={e => {
          e.preventDefault()
          onSkip()
        }}
      >
        <Icon glyph="view-close" size={28} />
      </button>

      <p className={clsx('mt0 mr3', stepCount == 1 && 'mb0')}>{text}</p>

      {stepCount > 1 && (
        <div className="flex justify-between items-center">
          <div className="muted">
            {stepIndex + 1} of {stepCount}
          </div>

          <button
            className="pop tooltipped tooltipped--w border-none cursor-pointer ml2"
            aria-label={last ? 'Finish' : 'Next'}
            onClick={e => {
              e.preventDefault()
              onNext()
            }}
          >
            <Icon glyph={last ? 'checkmark' : 'enter'} />
          </button>
        </div>
      )}
    </div>
  )
}

TourStep.propTypes = {
  text: PropTypes.string.isRequired,
  attachTo: PropTypes.string.isRequired,
  placement: PropTypes.oneOf([
    'top',
    'top-start',
    'top-end',
    'right',
    'right-start',
    'right-end',
    'bottom',
    'bottom-start',
    'bottom-end',
    'left',
    'left-start',
    'left-end',
  ]).isRequired,
  strategy: PropTypes.oneOf(['absolute', 'fixed']),
  onNext: PropTypes.func.isRequired,
  onSkip: PropTypes.func.isRequired,
  last: PropTypes.bool,
  visible: PropTypes.bool,
  stepIndex: PropTypes.number.isRequired,
  stepCount: PropTypes.number.isRequired,
  tourId: PropTypes.number.isRequired,
}

export default TourStep
